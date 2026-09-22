# Curated Skills Catalog

Complete catalog of recommended skills for DevOps/SRE engineers.

## Marketplace Sources

| Marketplace | Repository | Owner | Focus |
|-------------|------------|-------|-------|
| `lyon-skills` | `yieon-lyon/lyon-skills` | Lyon | Personal DevOps guidelines |
| `karpathy-skills` | `forrestchang/andrej-karpathy-skills` | forrestchang | LLM coding guardrails |
| `hashicorp` | `hashicorp/agent-skills` | HashiCorp | Terraform ecosystem |
| `grafana-skills` | `grafana/skills` | Grafana Labs | Observability ecosystem |
| `aws-skills-for-claude-code` | `whchoi98/aws-skills-for-claude-code` | whchoi98 | AWS operations & development |

## Current Setup (installed composition)

Reference composition as of 2026-09-22:

| Plugin | Version | Skills |
|--------|---------|--------|
| `lyon@lyon-skills` | 0.2.0 | `lyon`, `skill-manager`, `incident-management`, `alerting-process` |
| `andrej-karpathy-skills@karpathy-skills` | 1.0.0 | `karpathy-guidelines` |
| `terraform@hashicorp` | 1.0.0 | 16 Terraform skills (consolidated; see below) |
| `aws-skills-for-claude-code` | 1.4.0 | ~38 AWS/ops skills (see below) |
| `grafana-core@grafana-skills` | 0.1.0 | dashboarding, promql, grafana-oss, alloy, beyla, opentelemetry, alerting-irm |
| `grafana-lgtm@grafana-skills` | 0.1.0 | loki, tempo, prometheus, mimir, pyroscope |
| `grafana-cloud@grafana-skills` | 0.1.0 | adaptive-metrics, cloud-integrations, fleet-management, oncall-irm, and more |
| `grafana-k6@grafana-skills` | 0.1.0 | k6, k6-docs |

Standalone MCP servers (not plugin-bundled):

| MCP server | Scope | Command |
|------------|-------|---------|
| `terraform` | user | `docker run -i --rm -e TFE_TOKEN -e TFE_ADDRESS hashicorp/terraform-mcp-server` — registry search/provider docs; formerly bundled in the legacy hashicorp plugins |

## Grafana Skills (grafana/skills)

### grafana-core
| Skill | Description |
|-------|-------------|
| `dashboarding` | Dashboard design, panel types, variables, annotations |
| `promql` | PromQL query writing and optimization |
| `grafana-oss` | Grafana open-source deployment and configuration |
| `alloy` | Grafana Alloy configuration for telemetry collection |
| `beyla` | eBPF-based auto-instrumentation |
| `opentelemetry` | OTel integration patterns |
| `alerting-irm` | Alerting rules and incident response management |

### grafana-lgtm
| Skill | Description |
|-------|-------------|
| `loki` | LogQL queries, Loki architecture, log pipelines |
| `tempo` | Distributed tracing, TraceQL |
| `prometheus` | Prometheus configuration and federation |
| `mimir` | Long-term metrics storage, tenant isolation |
| `pyroscope` | Continuous profiling |

### grafana-cloud
| Skill | Description |
|-------|-------------|
| `adaptive-metrics` | Cost reduction via metric aggregation rules |
| `cloud-integrations` | AWS/GCP/Azure metric ingestion |
| `fleet-management` | Alloy fleet management at scale |
| `assistant-mcp` | Grafana Assistant MCP integration |

### grafana-k6
| Skill | Description |
|-------|-------------|
| `k6` | k6 load testing scripts and scenarios |
| `k6-docs` | k6 documentation writing and review |

## HashiCorp Skills (hashicorp/agent-skills)

> **Restructured 2026-09**: the former `terraform-code-generation`,
> `terraform-module-generation`, and `terraform-provider-development` plugins were
> removed upstream and consolidated into a single **`terraform`** plugin (plus
> **`packer`**). The legacy names can no longer be installed or updated. The legacy
> plugins bundled the Terraform MCP server — the consolidated plugin does not, so
> register it separately (see Current Setup above).

### terraform (consolidated — 16 skills)
| Skill | Description |
|-------|-------------|
| `terraform-style-guide` | Official HCL style conventions |
| `terraform-test` | Writing `.tftest.hcl` files, mock providers |
| `terraform-search-import` | Resource discovery and bulk import |
| `terraform-policy` | Policy as code (new) |
| `terraform-stacks` | Multi-region Terraform Stacks |
| `refactor-module` | Monolithic to modular transformation |
| `azure-verified-modules` | AVM certification requirements |
| `new-terraform-provider` | Provider scaffolding |
| `provider-resources` | CRUD operations with Plugin Framework |
| `provider-configuration` | Provider configuration (new) |
| `provider-ephemeral-resources` | Ephemeral resources (new) |
| `provider-framework-migration` | SDKv2 → Plugin Framework migration (new) |
| `provider-test-patterns` | Acceptance testing patterns |
| `provider-actions` | Lifecycle event operations |
| `provider-docs` | Registry documentation |
| `run-acceptance-tests` | Test execution guide |

### packer
| Skill | Description |
|-------|-------------|
| `packer` | Image building and HCP Packer registry workflows |

## AWS Skills (whchoi98/aws-skills-for-claude-code)

Single `aws-skills-for-claude-code` plugin (~38 skills). Key skills by category:

| Category | Skills |
|----------|--------|
| AWS core ops | `aws-infra`, `aws-iam`, `aws-security`, `aws-cost`, `aws-data`, `aws-messaging`, `aws-mcp` |
| IaC / architecture | `aws-iac` (CDK/CloudFormation), `cloud-architect`, `terraform`, `aws-sam`, `aws-amplify` |
| Observability | `aws-cloudwatch`, `aws-observability`, `cloudwatch-appsignals`, `datadog`, `dynatrace` |
| Migration | `aws-graviton-migration`, `arm-soc-migration`, `gcp-aws-migrate` |
| Workflow | `code-review`, `refactor`, `release`, `sync-docs` |
| AI / specialized | `aws-agentcore`, `strands`, `saas-builder`, `spark-troubleshooting`, `stripe`, `postman`, `figma` |

> Known issue: v1.4.0 fails to load in recent Claude Code builds due to an upstream
> hooks-schema bug (`Hook load failed: expected record`). Skills still resolve in
> most sessions; wait for an upstream fix or report at the source repo.

## Karpathy Skills (forrestchang/andrej-karpathy-skills)

| Skill | Description |
|-------|-------------|
| `karpathy-guidelines` | Think Before Coding, Simplicity First, Surgical Changes, Goal-Driven Execution |

## Version Tracking & Updates

```bash
# Check current installed versions
claude plugin list

# Refresh marketplace caches from git sources
claude plugin marketplace update

# Update a plugin (only fetches when the manifest version was bumped)
claude plugin update {plugin}@{marketplace}

# Restart Claude Code (new session) to apply
```

Publishing an update to `lyon-skills` itself: bump `version` in
`.claude-plugin/marketplace.json`, `.agents-plugin/marketplace.json`, and
`skill-registry.json`, then commit & push — consumers pick it up with the
two commands above.

## Contributing a New Skill

To add a skill to this catalog:

1. Verify it follows the Agent Skills standard
2. Test installation: `claude plugin marketplace add {owner}/{repo}`
3. Evaluate quality: concise, domain-specific, includes examples
4. Determine tier placement based on relevance to DevOps/SRE workflow
5. Submit PR to `yieon-lyon/lyon-skills` with catalog update
