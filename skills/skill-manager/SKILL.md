---
name: skill-manager
description: >
  Manage Claude Code skills marketplace plugins - install, update, list, and curate
  third-party skill collections from Grafana, AWS, HashiCorp, and community sources.
  Use when the user asks to install skills, manage plugins, check skill versions,
  or browse available marketplace skills. Includes a curated catalog of recommended
  DevOps/SRE skills for infrastructure engineers.
user-invocable: true
disable-model-invocation: true
license: MIT
metadata:
  author: Lyon
  version: "0.1.0"
---

# Skill Manager

Manage and curate Claude Code skill plugins from multiple marketplace sources.

## Reference Files

- `references/catalog.md` - Full curated catalog with installation commands

## Quick Commands

### List Installed Skills
```bash
claude plugin list
```

### Install from Marketplace
```bash
# Add a marketplace first
claude plugin marketplace add {owner}/{repo}

# Then install a specific plugin
claude plugin install {plugin-name}@{marketplace-name}
```

### Cross-Tool Install (npx skills)
```bash
npx skills add {owner}/{repo}
npx skills add {owner}/{repo}/{path-to-skill}
```

## Curated Skill Catalog

### Tier 1: Always Installed (Core Workflow)

| Plugin | Source | Purpose |
|--------|--------|---------|
| `lyon@lyon-skills` | `yieon-lyon/lyon-skills` | Personal DevOps guidelines |
| `andrej-karpathy-skills` | `forrestchang/andrej-karpathy-skills` | LLM coding behavior guardrails |

### Tier 2: Infrastructure & IaC

| Plugin | Source | Purpose |
|--------|--------|---------|
| `terraform-code-generation@hashicorp` | `hashicorp/agent-skills` | Terraform HCL style guide, testing, import |
| `terraform-module-generation@hashicorp` | `hashicorp/agent-skills` | Module refactoring, Terraform Stacks |
| `terraform-provider-development@hashicorp` | `hashicorp/agent-skills` | Provider development (resources, tests, docs) |
| `aws-skills-for-claude-code` | `zxkane/aws-skills` | AWS CDK, cost ops, serverless, agentic AI |

### Tier 3: Observability

| Plugin | Source | Purpose |
|--------|--------|---------|
| `grafana-lgtm@grafana-skills` | `grafana/skills` | Loki, Tempo, Prometheus, Mimir, Pyroscope |
| `grafana-core@grafana-skills` | `grafana/skills` | Dashboarding, PromQL, Alerting, Alloy, OTel |
| `grafana-cloud@grafana-skills` | `grafana/skills` | Adaptive metrics, Cloud integrations, Fleet |
| `grafana-k6@grafana-skills` | `grafana/skills` | k6 load testing |

### Tier 4: Specialized

| Plugin | Source | Purpose |
|--------|--------|---------|
| `grafana-plugins@grafana-skills` | `grafana/skills` | Plugin development, React 19 migration |
| `grafana-app-sdk@grafana-skills` | `grafana/skills` | Grafana App SDK development |

## Installation Playbook

### Fresh Setup
```bash
# 1. Add marketplaces
claude plugin marketplace add yieon-lyon/lyon-skills
claude plugin marketplace add forrestchang/andrej-karpathy-skills
claude plugin marketplace add hashicorp/agent-skills
claude plugin marketplace add grafana/skills
claude plugin marketplace add zxkane/aws-skills

# 2. Install core plugins
claude plugin install lyon@lyon-skills
claude plugin install andrej-karpathy-skills@karpathy-skills

# 3. Install IaC plugins
claude plugin install terraform-code-generation@hashicorp
claude plugin install terraform-module-generation@hashicorp

# 4. Install observability plugins
claude plugin install grafana-lgtm@grafana-skills
claude plugin install grafana-core@grafana-skills
```

### Update All
```bash
# Check for updates
claude plugin marketplace update

# Reinstall to get latest
claude plugin install {plugin}@{marketplace} --force
```

## Marketplace Architecture

Each marketplace follows the Agent Skills standard:

```
{repo}/
├── .claude-plugin/marketplace.json   # Claude Code manifest
├── .cursor-plugin/marketplace.json   # Cursor manifest (identical)
├── .agents-plugin/marketplace.json   # Codex manifest (identical)
├── skills/
│   └── {skill-name}/
│       ├── SKILL.md                  # Skill definition (frontmatter + body)
│       ├── references/               # On-demand reference docs
│       ├── scripts/                  # Executable helpers
│       └── assets/                   # Templates, schemas
└── skill-registry.json               # Optional flat index
```

### SKILL.md Frontmatter Fields

| Field | Required | Description |
|-------|----------|-------------|
| `name` | Yes | Lowercase, hyphens, max 64 chars |
| `description` | Yes | Max 1024 chars, include "Use when..." triggers |
| `license` | No | SPDX identifier |
| `user-invocable` | No | `true` (default) - show in `/` menu |
| `disable-model-invocation` | No | `false` (default) - allow auto-load |
| `allowed-tools` | No | Pre-approved tools for the skill |
| `metadata` | No | Custom key-value pairs |

## Adding a New Skill Source

When evaluating a new skill marketplace:

1. **Check structure**: Must have `.claude-plugin/marketplace.json`
2. **Verify SKILL.md**: Frontmatter with `name` and `description` fields
3. **Test locally**: `claude plugin marketplace add {owner}/{repo}` then preview
4. **Review content**: Skills should be concise (<500 lines), domain-specific
5. **Update catalog**: Add to the appropriate tier in this file
