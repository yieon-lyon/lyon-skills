# Terraform Patterns Reference

## Multi-Account Structure

### Account Layout
```
AWS Organization
├── {account-a}                   # Account A
│   ├── {env-1}                   # Environment 1
│   ├── {env-2}                   # Environment 2
│   └── {env-N}                   # Environment N
└── {account-b}                   # Account B
    ├── {env-1}                   # Environment 1
    └── {env-N}                   # Environment N
```

### State File Convention
```
s3://{company}-terraform-state/
  aws/{account-a}/{env-1}/eks/terraform.tfstate
  aws/{account-a}/{env-2}/eks/terraform.tfstate
  aws/{account-a}/{env-N}/eks/terraform.tfstate
  aws/{account-a}/general/chatbot-slack/terraform.tfstate
  aws/{account-b}/{env-1}/eks/terraform.tfstate
  aws/{account-b}/{env-N}/eks/terraform.tfstate
```

## Symlink Module Pattern

For multi-environment deployments sharing the same Terraform code:

```
terraform/modules/aws/eks/
├── vpc.tf          # VPC, subnets, NAT gateways
├── eks.tf          # EKS cluster, addons, IRSA
├── karpenter.tf    # Karpenter controller, NodePools, EC2NodeClass

terraform/aws/{account-a}/{env-1}/eks/
├── terraform.tf      # Backend config (unique per env)
├── variables.tf      # Variable declarations
├── terraform.tfvars  # Environment-specific values
├── vpc.tf -> ../../../modules/aws/eks/vpc.tf
├── eks.tf -> ../../../modules/aws/eks/eks.tf
└── karpenter.tf -> ../../../modules/aws/eks/karpenter.tf
```

**Why symlinks over module calls?**
- Terraform state tracks resources directly (no module wrapper indirection)
- `terraform plan` output is cleaner and directly shows resource changes
- Easier to selectively override one file per environment

## Provider Configuration Patterns

```hcl
# Required providers with version pinning
terraform {
  required_version = ">= 1.3"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.0"
    }
  }
}

# Provider with assume_role for cross-account
provider "aws" {
  region = var.region

  default_tags {
    tags = {
      Environment = var.environment
      ManagedBy   = "terraform"
      Team        = "devops"
    }
  }
}
```

## Module Design Rules

1. **Inputs**: Use `object()` types for related variables, add `validation {}` blocks
2. **Outputs**: Only expose what consumers need, add `description`
3. **Locals**: Compute derived values in `locals {}`, never in resource blocks
4. **Data sources**: Prefer data sources over hardcoded ARNs/IDs
5. **Lifecycle**: Use `ignore_changes` sparingly, document WHY when used

## GitHub Actions CI/CD

```yaml
# Workflow naming convention
provisioning-{account}.yml    # Per-account provisioning
provisioning-third-party.yml  # External integrations (Datadog, etc.)
```

Standard job pattern:
1. `terraform fmt -check` - Style validation
2. `terraform init` - Initialize backend
3. `terraform validate` - Configuration validation
4. `terraform plan` - Preview changes (PR comment)
5. `terraform apply -auto-approve` - Apply on merge to master
