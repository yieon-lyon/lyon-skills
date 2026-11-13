# AGENTS.md

Instructions for AI agents working with this repository.

## Repository Purpose

Personal skills marketplace by Lyon (DevOps/SRE Engineer, Grafana Champion).
Provides AI-assisted development skills for Claude Code, Cursor, and other tools
supporting the Agent Skills standard.

## Structure Overview

```
.claude-plugin/marketplace.json    # Claude Code marketplace manifest
.cursor-plugin/marketplace.json    # Cursor marketplace manifest (identical)
.agents-plugin/marketplace.json    # Codex marketplace manifest (identical)
skill-registry.json                # Machine-readable skill index
skills/
  lyon/
    SKILL.md                       # Personal DevOps engineering guidelines
    references/
      terraform-patterns.md        # Terraform IaC conventions
      eks-operations.md            # EKS cluster management
      observability.md             # Grafana LGTM + Datadog patterns
  skill-manager/
    SKILL.md                       # Marketplace plugin management
    references/
      catalog.md                   # Curated skills catalog
template/SKILL.md                  # Starter template for new skills
scripts/lint-skills.sh             # SKILL.md validation
```

## Key Architecture

- Single source of truth in `skills/` for all platforms
- Three marketplace manifests (identical) for Claude Code, Cursor, Codex
- Skills follow the Agent Skills standard (agentskills.io)

## When Adding New Skills

1. Create `skills/{skill-name}/SKILL.md` using `template/SKILL.md`
2. Add `name` (lowercase, hyphens, max 64 chars) and `description` (max 1024 chars, include "Use when...")
3. Run `./scripts/lint-skills.sh` to validate
4. Register in all three marketplace manifests and `skill-registry.json`

## Working Style

- **Respond in Korean (한국어)** — all answers, questions, and progress updates
  must be in Korean. English only inside code, commit messages, and skill file content
- **Minimal comments** — only comments that state constraints the code cannot
  express; no narration, no change-explanations, no restating the obvious
- **Instruction-first** — execute the requested task first; for work not
  explicitly requested (refactors, extra reviews, scope expansion), confirm
  with the user before proceeding unless strictly necessary
- **No git actions on your own** — never create branches, commit, push, tag,
  or open PRs without an explicit instruction in the current conversation;
  finish the edits, then ask (see `skills/git-discipline`)

## Do Not

- Add internal credentials or infrastructure-specific secrets
- Put "When to Use" sections in skill body (use `description` frontmatter)
- Edit one marketplace manifest without updating the other two
- Hardcode paths - use relative paths or `${CLAUDE_PLUGIN_ROOT}`
