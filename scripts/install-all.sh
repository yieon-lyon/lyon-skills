#!/usr/bin/env bash
set -euo pipefail

# Install all recommended marketplaces and plugins for a fresh Claude Code setup.
# Usage:
#   ./scripts/install-all.sh                # install Tier 1 + 2 + 3
#   ./scripts/install-all.sh --tier 1       # install Tier 1 only
#   ./scripts/install-all.sh --tier 1,2     # install Tier 1 and 2
#   ./scripts/install-all.sh --all          # install all tiers (including 4)
#   ./scripts/install-all.sh --dry-run      # print commands without executing
#   ./scripts/install-all.sh --force        # reinstall even if already present

TIERS="1,2,3"
DRY_RUN=0
FORCE=0

while [ $# -gt 0 ]; do
  case "$1" in
    --tier)
      TIERS="$2"
      shift 2
      ;;
    --all)
      TIERS="1,2,3,4"
      shift
      ;;
    --dry-run)
      DRY_RUN=1
      shift
      ;;
    --force)
      FORCE=1
      shift
      ;;
    -h|--help)
      sed -n '3,12p' "$0"
      exit 0
      ;;
    *)
      echo "Unknown option: $1" >&2
      exit 1
      ;;
  esac
done

if ! command -v claude >/dev/null 2>&1; then
  echo "ERROR: 'claude' CLI not found. Install Claude Code first: https://claude.com/claude-code" >&2
  exit 1
fi

# Format: "marketplace-name|owner/repo"
MARKETPLACES=(
  "lyon-skills|yieon-lyon/lyon-skills"
  "karpathy-skills|forrestchang/andrej-karpathy-skills"
  "hashicorp|hashicorp/agent-skills"
  "grafana-skills|grafana/skills"
  "aws-skills-for-claude-code|whchoi98/aws-skills-for-claude-code"
)

# Format: "tier|plugin@marketplace"
PLUGINS=(
  # Tier 1 - Core Workflow
  "1|lyon@lyon-skills"
  "1|andrej-karpathy-skills@karpathy-skills"

  # Tier 2 - Infrastructure & IaC
  "2|terraform-code-generation@hashicorp"
  "2|terraform-module-generation@hashicorp"
  "2|terraform-provider-development@hashicorp"
  "2|aws-skills-for-claude-code@aws-skills-for-claude-code"

  # Tier 3 - Observability
  "3|grafana-lgtm@grafana-skills"
  "3|grafana-core@grafana-skills"
  "3|grafana-cloud@grafana-skills"
  "3|grafana-k6@grafana-skills"

  # Tier 4 - Specialized
  "4|grafana-plugins@grafana-skills"
  "4|grafana-app-sdk@grafana-skills"
)

run() {
  if [ "$DRY_RUN" -eq 1 ]; then
    echo "[dry-run] $*"
  else
    echo "+ $*"
    "$@"
  fi
}

tier_selected() {
  local tier="$1"
  case ",$TIERS," in
    *",$tier,"*) return 0 ;;
    *) return 1 ;;
  esac
}

marketplace_installed() {
  claude plugin marketplace list 2>/dev/null | grep -qE "❯[[:space:]]+$1$"
}

plugin_installed() {
  claude plugin list 2>/dev/null | grep -qE "❯[[:space:]]+$1$"
}

echo "=== Adding marketplaces ==="
for entry in "${MARKETPLACES[@]}"; do
  name="${entry%%|*}"
  repo="${entry##*|}"
  if [ "$FORCE" -eq 0 ] && marketplace_installed "$name"; then
    echo "= $name already added, skipping"
    continue
  fi
  run claude plugin marketplace add "$repo"
done

echo ""
echo "=== Installing plugins (tiers: $TIERS) ==="
for entry in "${PLUGINS[@]}"; do
  tier="${entry%%|*}"
  spec="${entry##*|}"
  if ! tier_selected "$tier"; then
    continue
  fi
  if [ "$FORCE" -eq 0 ] && plugin_installed "$spec"; then
    echo "= $spec already installed, skipping"
    continue
  fi
  if [ "$FORCE" -eq 1 ]; then
    run claude plugin install "$spec" --force
  else
    run claude plugin install "$spec"
  fi
done

echo ""
echo "=== Done ==="
if [ "$DRY_RUN" -eq 0 ]; then
  echo "Run 'claude plugin list' to verify installation."
fi
