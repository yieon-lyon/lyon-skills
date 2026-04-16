---
name: lyon
description: >
  Lyon's DevOps/SRE engineering guidelines for production infrastructure.
  Covers Terraform IaC patterns (multi-account AWS, S3 backend, symlink module architecture),
  AWS EKS operations (Karpenter Helm chart patterns, service-to-NodePool mapping, cluster upgrades),
  Grafana LGTM observability stack (Loki distributed, Grafana, Tempo, Mimir, OpenTelemetry auto-instrumentation),
  Cilium eBPF networking (kube-proxy replacement, Tetragon runtime security, Hubble observability),
  ArgoCD GitOps (multi-env Application templates, AppProject isolation), Datadog integration,
  and infrastructure decision-making.
  Use when writing Terraform HCL, managing EKS clusters, configuring Cilium/Tetragon,
  designing observability pipelines, setting up ArgoCD GitOps, reviewing infrastructure PRs,
  or making DevOps architectural decisions.
license: MIT
metadata:
  author: Lyon
  version: "0.1.0"
  grafana_champion: true
---

# Lyon's DevOps Engineering Guidelines

Personal engineering guidelines for production infrastructure management.
Optimized for AWS-centric, Kubernetes-native, observability-first environments.

## Identity & Context

- **Role**: DevOps / SRE Engineer
- **Community**: Grafana Champion
- **Region**: ap-northeast-2 (Seoul)
- **Primary Stack**: Terraform + AWS EKS + Grafana LGTM + Datadog

## Reference Files

- `references/terraform-patterns.md` - Terraform IaC patterns and conventions
- `references/eks-operations.md` - EKS cluster management, Karpenter Helm chart patterns
- `references/observability.md` - Grafana LGTM stack, Loki distributed, OTel, Datadog
- `references/cilium-network.md` - Cilium eBPF networking, Tetragon runtime security
- `references/gitops.md` - ArgoCD GitOps patterns, multi-env Application templates

## 1. Infrastructure as Code Principles

### Terraform Conventions

**Directory naming**: `terraform/aws/{ACCOUNT}/{ENV|general}/{SERVICE}/`

```
terraform/
  aws/
    {account-a}/         # Account A
      {env-1}/eks/
      {env-2}/eks/
      {env-N}/eks/
      general/           # Cross-environment resources
        datadog/
        cloudwatch-alarm/
        chatbot-slack/
    {account-b}/         # Account B
      {env-1}/eks/
      {env-N}/eks/
      general/
        datadog/
  modules/aws/           # Reusable modules
    eks/
    chatbot-slack/
    cloudwatch-alarm/
    datadog/
```

**State management**: Always use S3 backend with DynamoDB locking.

```hcl
terraform {
  backend "s3" {
    bucket         = "{company}-terraform-state"
    key            = "aws/{account}/{env}/eks/terraform.tfstate"
    region         = "ap-northeast-2"
    dynamodb_table = "{company}-terraform-lock"
    encrypt        = true
  }
}
```

**Symlink architecture**: For multi-environment EKS deployments, use symlinks from environment directories to common module files. This maintains per-environment state while sharing the same Terraform code.

```bash
# Environment-specific: terraform.tf, variables.tf, terraform.tfvars
# Symlinked from module: vpc.tf, eks.tf, karpenter.tf
ln -sf ../../../modules/aws/eks/vpc.tf .
ln -sf ../../../modules/aws/eks/eks.tf .
ln -sf ../../../modules/aws/eks/karpenter.tf .
```

### Terraform Decision Rules

1. **Module vs Inline**: If a resource group is used across 2+ environments, extract to a module
2. **Variable validation**: Always add `validation {}` blocks for user-facing variables
3. **Outputs**: Only export values that downstream modules or operators actually need
4. **Provider versioning**: Pin providers with `~>` for minor version flexibility
5. **No hardcoded values**: Use `locals {}` for computed values, `variable {}` for configurable ones

## 2. Kubernetes & EKS Operations

### EKS Cluster Standards

| Property | Standard |
|----------|----------|
| Kubernetes version | Latest stable (currently 1.33) |
| Node management | Karpenter v1 (preferred) + Managed Node Groups (system) |
| CNI | VPC CNI + Cilium (eBPF chaining) |
| Region | ap-northeast-2 |
| Auth | aws-auth ConfigMap -> EKS Access Entries migration |

### Karpenter Patterns

```yaml
# NodePool: prefer spot, fallback to on-demand
# Use consolidation policy for cost optimization
# Set disruption budgets to prevent mass eviction
apiVersion: karpenter.sh/v1
kind: NodePool
metadata:
  name: default
spec:
  disruption:
    consolidationPolicy: WhenEmptyOrUnderutilized
    budgets:
      - nodes: "10%"
```

### Upgrade Strategy

1. **Pre-flight**: Check addon compatibility, review changelog, test in lowest environment first
2. **Order**: Control plane -> Addons -> Karpenter NodePool -> Node Groups
3. **Validation**: Pod disruption budgets respected, no stuck pods, metrics flowing
4. **Rollback**: Always have previous version AMI available

## 3. Networking & Security

### Cilium (eBPF-based)

| Feature | Configuration |
|---------|---------------|
| kube-proxy replacement | `kubeProxyReplacement: true` |
| CNI mode | AWS VPC CNI chaining (native routing, no overlay) |
| Hubble | DNS, drops, flows, TCP, HTTP metrics via eBPF |
| Tetragon | Runtime security — process exec, file access, privilege escalation detection |
| L7 proxy | Disabled (use Datadog/Tempo for L7 observability) |

### ArgoCD GitOps

- All manifests in Git — no manual `kubectl apply` on upper environments
- Helm values per service: `{service}-values.yaml`
- AppProject per environment with namespace isolation
- Auto-sync for lower envs; manual sync for upper environments
- Application types: api (Deployment), task (worker), cron (CronJob), rollout (Argo Rollout)

## 4. Observability Philosophy

### Grafana LGTM Stack (Preferred)

| Component | Purpose | Priority |
|-----------|---------|----------|
| **Grafana** | Visualization & dashboards | Core |
| **Loki** | Log aggregation (LogQL) | Core |
| **Tempo** | Distributed tracing | High |
| **Mimir** | Long-term metrics storage | High |
| **Alloy/OTel** | Collection & routing | Core |

**Design principle**: Instrument once with OpenTelemetry, route to multiple backends.

### Datadog Integration

For teams requiring commercial APM alongside open-source observability:
- Use Terraform module for consistent Datadog integration across accounts
- Datadog Agent as DaemonSet in EKS
- Forward CloudWatch metrics via AWS integration
- Unified tagging: `env`, `service`, `team`

### Monitoring Decision Tree

```
Need monitoring?
  -> Metrics: Prometheus/Mimir + Grafana dashboards
  -> Logs: Loki + Grafana Explore
  -> Traces: Tempo + Grafana Traces
  -> Network: Cilium Hubble + Grafana (DNS, flows, drops)
  -> Security: Tetragon + Grafana (process exec, file access)
  -> APM (commercial): Datadog
  -> AWS-native alerts: CloudWatch Alarm + Chatbot -> Slack
```

## 5. Code Review Standards

When reviewing infrastructure PRs:

### Must Check
- [ ] State file impact: Will this destroy/recreate critical resources?
- [ ] Security: No hardcoded secrets, IAM least privilege
- [ ] Cost: Instance types, storage classes, spot vs on-demand
- [ ] Blast radius: What breaks if this fails?

### Should Check
- [ ] Naming consistency with existing conventions
- [ ] Tags: `Name`, `Environment`, `Team`, `ManagedBy: terraform`
- [ ] Outputs documented for downstream consumers
- [ ] No unnecessary `depends_on` (let Terraform infer)

### Nice to Have
- [ ] README updated if behavior changes
- [ ] Example tfvars for new variables

## 6. Decision-Making Framework

### When Choosing Tools

| Criterion | Weight |
|-----------|--------|
| Open-source & community-driven | High |
| Kubernetes-native | High |
| Terraform provider available | Medium |
| Active maintenance & CNCF/Grafana backing | Medium |
| Team familiarity | Medium |

### When Solving Problems

1. **Understand first**: Read existing code, check git blame, understand why it was done that way
2. **Smallest change**: Fix the actual problem, don't refactor surrounding code
3. **Validate**: `terraform plan` before any apply, check state drift
4. **Document intent**: Commit messages explain WHY, not WHAT

## 7. Communication Style

- Prefer **concise, direct** responses - no filler
- Use **Korean** for internal team communication when appropriate
- Structure with **tables and code blocks** over prose
- Always include **practical examples** over theory
- When uncertain, state assumptions explicitly before proceeding
