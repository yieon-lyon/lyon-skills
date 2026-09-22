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
| `terraform@hashicorp` | `hashicorp/agent-skills` | All Terraform skills consolidated (16): style guide, testing, import, modules, stacks, policy, provider development |
| `aws-skills-for-claude-code` | `whchoi98/aws-skills-for-claude-code` | AWS ops (IaC, cost, IAM, observability), Datadog, code review |

> **HashiCorp restructure (2026-09)**: the former `terraform-code-generation`,
> `terraform-module-generation`, and `terraform-provider-development` plugins were
> removed upstream and consolidated into a single `terraform` plugin (plus `packer`).
> If you still have the legacy three installed, they can no longer be updated —
> uninstall them and install `terraform@hashicorp`.
>
> The legacy plugins bundled the **Terraform MCP server** (registry search tools);
> the consolidated plugin does not. Re-register it manually after migrating:
>
> ```bash
> claude mcp add --scope user terraform -- docker run -i --rm -e TFE_TOKEN -e TFE_ADDRESS hashicorp/terraform-mcp-server
> ```

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

### Fresh Setup (one shot)

The repo ships an install script that adds every marketplace and plugin in
one go. Use this on a new machine:

```bash
./scripts/install-all.sh              # Tier 1 + 2 + 3
./scripts/install-all.sh --all        # include Tier 4
./scripts/install-all.sh --tier 1     # core only
./scripts/install-all.sh --dry-run    # preview without changes
```

It is idempotent — already-installed marketplaces and plugins are skipped.

### Manual Setup (per-plugin)

```bash
# 1. Add marketplaces
claude plugin marketplace add yieon-lyon/lyon-skills
claude plugin marketplace add forrestchang/andrej-karpathy-skills
claude plugin marketplace add hashicorp/agent-skills
claude plugin marketplace add grafana/skills
claude plugin marketplace add whchoi98/aws-skills-for-claude-code

# 2. Install core plugins
claude plugin install lyon@lyon-skills
claude plugin install andrej-karpathy-skills@karpathy-skills

# 3. Install IaC plugins
claude plugin install terraform@hashicorp
claude plugin install aws-skills-for-claude-code@aws-skills-for-claude-code

# 4. Install observability plugins
claude plugin install grafana-lgtm@grafana-skills
claude plugin install grafana-core@grafana-skills
```

## Updating Skills

### Consumer side (any machine — CLI and desktop app share `~/.claude`)

```bash
# 1. Refresh marketplace caches from their git sources (all, or one by name)
claude plugin marketplace update
claude plugin marketplace update {marketplace-name}

# 2. Update installed plugins (per plugin; -y skips the confirmation prompt)
claude plugin update {plugin}@{marketplace}

# 3. Restart Claude Code (new session) to apply
```

Notes:
- `claude plugin update` fetches new files **only when the manifest `version`
  changed** — "already at the latest version" with a stale version number means
  the publisher forgot to bump it.
- `claude plugin install` has **no `--force` flag**; to force-reinstall at the
  same version: `claude plugin uninstall -y {plugin}` then `install` again.
- The Claude **desktop app** uses the same plugin store — run the commands in
  any terminal, then start a new session in the app.

### Publisher side (releasing a skill update)

1. Edit skills, run validation (`./scripts/lint-skills.sh` or `claude plugin validate .`)
2. **Bump `version`** in every manifest — `.claude-plugin/marketplace.json`,
   `.agents-plugin/marketplace.json`, `skill-registry.json`. Without the bump,
   installed copies will never pull the update.
3. Commit and push to the repo the marketplace was added from
4. Optionally tag the release: `claude plugin tag`
5. Directory sites (e.g. awesomeclaudeplugins.com) re-crawl GitHub automatically —
   no manual action; they display marketplace-manifest metadata (name, version,
   description, keywords), not individual skill files

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
