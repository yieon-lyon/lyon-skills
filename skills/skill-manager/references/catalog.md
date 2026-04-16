# Curated Skills Catalog

Complete catalog of recommended skills for DevOps/SRE engineers.

## Marketplace Sources

| Marketplace | Repository | Owner | Focus |
|-------------|------------|-------|-------|
| `lyon-skills` | `yieon-lyon/lyon-skills` | Lyon | Personal DevOps guidelines |
| `karpathy-skills` | `forrestchang/andrej-karpathy-skills` | forrestchang | LLM coding guardrails |
| `hashicorp` | `hashicorp/agent-skills` | HashiCorp | Terraform ecosystem |
| `grafana-skills` | `grafana/skills` | Grafana Labs | Observability ecosystem |
| `aws-skills` | `zxkane/aws-skills` | zxkane | AWS development |

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

### terraform-code-generation
| Skill | Description |
|-------|-------------|
| `terraform-style-guide` | Official HCL style conventions |
| `terraform-test` | Writing `.tftest.hcl` files, mock providers |
| `terraform-search-import` | Resource discovery and bulk import |
| `azure-verified-modules` | AVM certification requirements |

### terraform-module-generation
| Skill | Description |
|-------|-------------|
| `refactor-module` | Monolithic to modular transformation |
| `terraform-stacks` | Multi-region Terraform Stacks |

### terraform-provider-development
| Skill | Description |
|-------|-------------|
| `new-terraform-provider` | Provider scaffolding |
| `provider-resources` | CRUD operations with Plugin Framework |
| `provider-test-patterns` | Acceptance testing patterns |
| `provider-actions` | Lifecycle event operations |
| `provider-docs` | Registry documentation |
| `run-acceptance-tests` | Test execution guide |

## AWS Skills (zxkane/aws-skills)

### aws-common
| Skill | Description |
|-------|-------------|
| `aws-mcp-setup` | MCP server configuration for AWS tools |

### aws-cdk
| Skill | Description |
|-------|-------------|
| `aws-cdk-development` | CDK infrastructure as code patterns |

### aws-cost-ops
| Skill | Description |
|-------|-------------|
| `aws-cost-operations` | Cost optimization and monitoring |

### serverless-eda
| Skill | Description |
|-------|-------------|
| `aws-serverless-eda` | Serverless and event-driven architecture |

### aws-agentic-ai
| Skill | Description |
|-------|-------------|
| `aws-agentic-ai` | Bedrock AgentCore for AI agents |

## Karpathy Skills (forrestchang/andrej-karpathy-skills)

| Skill | Description |
|-------|-------------|
| `karpathy-guidelines` | Think Before Coding, Simplicity First, Surgical Changes, Goal-Driven Execution |

## Version Tracking

Track installed versions and update availability:

```bash
# Check current installed versions
claude plugin list --verbose

# Compare with latest marketplace versions
claude plugin marketplace update
```

## Contributing a New Skill

To add a skill to this catalog:

1. Verify it follows the Agent Skills standard
2. Test installation: `claude plugin marketplace add {owner}/{repo}`
3. Evaluate quality: concise, domain-specific, includes examples
4. Determine tier placement based on relevance to DevOps/SRE workflow
5. Submit PR to `yieon-lyon/lyon-skills` with catalog update
