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

## Mandatory Tagging Strategy

**Every AWS resource written in Terraform MUST carry these tags. No exceptions.**

| Tag | Required | Value | Notes |
|-----|----------|-------|-------|
| `Team` | **Yes** | Owning team/chapter (e.g. `devops`, `backend`, `data`) | Ownership & IAM access control |
| `Env` | **Yes** | `prod` / `staging` / `qa` / `dev` / `alpha` / ... | **Use `general` when no single environment applies** (cross-env/shared resources) |
| `Service` | **Yes** | Service or component name (e.g. `eks`, `datadog`, `chatbot-slack`) | Cost allocation & resource grouping |
| `ManagedBy` | Recommended | `terraform` | Distinguishes IaC-managed from hand-made resources |
| `Name` | Recommended | Resource-specific name | Console readability |

### Why these tags (tagging objectives)

A consistent tagging strategy across AWS resources achieves:

- **Resource management & cleanup** — environment/owner identification, lifecycle management
- **Cost visibility & allocation** — per-chapter / per-service cost analysis and budget control
- **Automation** — deploy pipelines, backup schedules keyed off tags
- **Access control & security** — IAM policies conditioned on resource tags

| Tag category | Purpose | Primary tags |
|--------------|---------|--------------|
| Resource cleanup | Env/owner separation, lifecycle management | `Env`, `Team`, `ManagedBy` |
| Cost allocation | Chapter/service cost analysis, budget control | `Team`, `Service`, `Env` |
| Automation | Deploy pipelines, backup schedule automation | `Service`, `Env` |
| Access control | IAM policy integration (`aws:ResourceTag` conditions) | `Team`, `Env` |

### Implementation pattern

Apply the mandatory tags at the **provider level** via `default_tags` so every resource inherits them, and add `Name`/resource-specific tags at the resource level:

```hcl
provider "aws" {
  region = var.region

  default_tags {
    tags = {
      Team      = var.team          # REQUIRED — owning team/chapter
      Env       = var.environment   # REQUIRED — env name, or "general" if cross-env
      Service   = var.service       # REQUIRED — service/component name
      ManagedBy = "terraform"
    }
  }
}

# Resource-level: add Name (and overrides) on top of inherited default_tags
resource "aws_security_group" "this" {
  name = "${var.service}-${var.environment}"
  # ...

  tags = {
    Name = "${var.service}-${var.environment}"
  }
}
```

Guard the mandatory tags with variable validation:

```hcl
variable "environment" {
  type        = string
  description = "Environment name. Use \"general\" for cross-environment resources."

  validation {
    condition     = contains(["prod", "staging", "qa", "dev", "alpha", "general"], var.environment)
    error_message = "Env must be one of prod/staging/qa/dev/alpha, or \"general\" when no single environment applies."
  }
}
```

**Rules of thumb:**

- If a module creates resources that don't inherit `default_tags` (e.g. some non-AWS providers, `aws_autoscaling_group` tag blocks, launch template `tag_specifications`), pass the three mandatory tags explicitly.
- Resources living under `{account}/general/` (cross-environment: Datadog integration, CloudWatch alarms, Chatbot) always use `Env = "general"`.
- Karpenter-launched nodes: propagate tags via EC2NodeClass `spec.tags` (`Team`, `Env`, `Service`).
- In code review, missing `Team`/`Env`/`Service` tags are a **blocking** finding, not a nice-to-have.

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
