# lyon-skills

DevOps & SRE skills for AI coding assistants by **Lyon** ([Grafana Champion](https://grafana.com/community/champions/)).

Skills for Terraform IaC, AWS EKS operations, Grafana LGTM observability, and a curated marketplace catalog — built on the [Agent Skills](https://agentskills.io) standard.

## Skills

| Skill | Description |
|-------|-------------|
| `lyon` | Personal DevOps engineering guidelines — Terraform patterns, EKS/Karpenter operations, Grafana LGTM stack, code review standards, and decision-making framework |
| `skill-manager` | Marketplace plugin management — install, update, and curate skills from Grafana, HashiCorp, AWS, and community sources |

## Installation

### One-shot full setup (recommended for new machines)

Installs every marketplace and plugin in the curated catalog (Tier 1–3 by default):

```bash
# From a cloned repo
./scripts/install-all.sh

# Or directly from GitHub without cloning
curl -fsSL https://raw.githubusercontent.com/yieon-lyon/lyon-skills/master/scripts/install-all.sh | bash
```

Options:

```bash
./scripts/install-all.sh --tier 1        # core workflow only
./scripts/install-all.sh --tier 1,2      # core + IaC
./scripts/install-all.sh --all           # include Tier 4 (specialized)
./scripts/install-all.sh --dry-run       # preview commands
./scripts/install-all.sh --force         # reinstall existing plugins
```

The script is idempotent — already-added marketplaces and installed plugins are skipped.

### Manual install (single plugin)

#### Claude Code

```bash
claude plugin marketplace add yieon-lyon/lyon-skills
claude plugin install lyon@lyon-skills
```

#### Cursor

Settings → Rules, Skills, Subagents → Add from GitHub → `https://github.com/yieon-lyon/lyon-skills`

#### npx skills (cross-tool)

```bash
npx skills add yieon-lyon/lyon-skills
```

## Repository Structure

```
.claude-plugin/marketplace.json       # Claude Code marketplace manifest
.cursor-plugin/marketplace.json       # Cursor marketplace manifest
.agents-plugin/marketplace.json       # Codex marketplace manifest
skill-registry.json                   # Machine-readable skill index
skills/
  lyon/
    SKILL.md                          # DevOps engineering guidelines
    references/
      terraform-patterns.md           # Terraform IaC conventions
      eks-operations.md               # EKS cluster & Karpenter operations
      observability.md                # Grafana LGTM + Datadog patterns
  skill-manager/
    SKILL.md                          # Marketplace plugin management
    references/
      catalog.md                      # Curated skills catalog
template/SKILL.md                     # Starter template for new skills
scripts/install-all.sh                # One-shot install of all curated marketplaces + plugins
scripts/lint-skills.sh                # SKILL.md validation
```

## Curated Marketplace Catalog

Skills I use and recommend, organized by tier:

### Tier 1 — Core Workflow
| Source | Focus |
|--------|-------|
| [yieon-lyon/lyon-skills](https://github.com/yieon-lyon/lyon-skills) | Personal DevOps guidelines |
| [forrestchang/andrej-karpathy-skills](https://github.com/forrestchang/andrej-karpathy-skills) | LLM coding behavior guardrails |

### Tier 2 — Infrastructure & IaC
| Source | Focus |
|--------|-------|
| [hashicorp/agent-skills](https://github.com/hashicorp/agent-skills) | Terraform style guide, testing, modules, stacks, provider development |
| [zxkane/aws-skills](https://github.com/zxkane/aws-skills) | AWS CDK, cost ops, serverless, agentic AI |

### Tier 3 — Observability
| Source | Focus |
|--------|-------|
| [grafana/skills](https://github.com/grafana/skills) | Grafana LGTM (Loki, Tempo, Prometheus, Mimir), dashboarding, PromQL, Alerting, Alloy, k6 |

## What's Inside `lyon` Skill

- **Terraform conventions** — multi-account AWS directory structure, S3 backend, symlink module pattern
- **EKS operations** — Karpenter v1 NodePool/EC2NodeClass templates, cluster upgrade procedure, autoscaling decision matrix
- **Observability philosophy** — Grafana LGTM-first, OpenTelemetry collection, Datadog integration, CloudWatch alarm patterns
- **Code review standards** — infrastructure PR checklist (state impact, security, cost, blast radius)
- **Decision-making framework** — tool selection criteria, problem-solving approach

## Validation

```bash
./scripts/lint-skills.sh
```

Checks: frontmatter presence, required fields (`name`, `description`), name format, directory match, line count, trigger phrases.

## Contributing

1. Copy `template/SKILL.md` to `skills/{your-skill-name}/SKILL.md`
2. Fill in frontmatter (`name`, `description` with "Use when..." triggers)
3. Add reference docs to `references/` if needed (keep SKILL.md under 500 lines)
4. Run `./scripts/lint-skills.sh` to validate
5. Register in all three marketplace manifests and `skill-registry.json`

## Author

**Lyon** — DevOps / SRE Engineer, [Grafana Champion](https://grafana.com/community/champions/)

- GitHub: [yieon-lyon](https://github.com/yieon-lyon)
- Blog: [velog.io/@yieon](https://velog.io/@yieon)
- Grafana Community: [community.grafana.com/u/lyon](https://community.grafana.com/u/lyon/summary)

## License

MIT
