#!/usr/bin/env bash
set -euo pipefail

# Lint SKILL.md files for Agent Skills standard compliance
# Usage: ./scripts/lint-skills.sh [skills-directory]

SKILLS_DIR="${1:-skills}"
ERRORS=0
WARNINGS=0

lint_skill() {
  local skill_file="$1"
  local skill_dir
  skill_dir=$(dirname "$skill_file")
  local skill_name
  skill_name=$(basename "$skill_dir")

  echo "Checking $skill_file"

  # Check frontmatter exists
  if ! head -1 "$skill_file" | grep -q "^---$"; then
    echo "  ERROR: Missing YAML frontmatter"
    ((ERRORS++))
    return
  fi

  # Check required fields
  if ! grep -q "^name:" "$skill_file"; then
    echo "  ERROR: Missing 'name' field in frontmatter"
    ((ERRORS++))
  fi

  if ! grep -q "^description:" "$skill_file"; then
    echo "  ERROR: Missing 'description' field in frontmatter"
    ((ERRORS++))
  fi

  # Check name matches directory
  local declared_name
  declared_name=$(grep "^name:" "$skill_file" | head -1 | sed 's/^name: *//' | tr -d '"'"'"'')
  if [ "$declared_name" != "$skill_name" ]; then
    echo "  ERROR: name '$declared_name' does not match directory '$skill_name'"
    ((ERRORS++))
  fi

  # Check name format (lowercase, hyphens, max 64 chars)
  if ! echo "$declared_name" | grep -qE '^[a-z][a-z0-9-]{0,63}$'; then
    echo "  ERROR: name must be lowercase letters, numbers, hyphens (max 64 chars)"
    ((ERRORS++))
  fi

  # Check description length
  local desc_line
  desc_line=$(grep "^description:" "$skill_file" | head -1)
  if [ ${#desc_line} -gt 1024 ]; then
    echo "  WARNING: description exceeds 1024 characters"
    ((WARNINGS++))
  fi

  # Check body exists (has content after frontmatter)
  local body_start
  body_start=$(awk '/^---$/{count++; if(count==2) {print NR; exit}}' "$skill_file")
  if [ -z "$body_start" ]; then
    echo "  ERROR: No closing frontmatter delimiter"
    ((ERRORS++))
  else
    local body_lines
    body_lines=$(tail -n +"$((body_start + 1))" "$skill_file" | grep -c '[^ ]' || true)
    if [ "$body_lines" -eq 0 ]; then
      echo "  ERROR: Skill body is empty"
      ((ERRORS++))
    fi
  fi

  # Check line count
  local total_lines
  total_lines=$(wc -l < "$skill_file" | tr -d ' ')
  if [ "$total_lines" -gt 500 ]; then
    echo "  WARNING: $total_lines lines (recommended max: 500)"
    ((WARNINGS++))
  fi

  # Check for "Use when" in description
  if ! grep -A 20 "^description:" "$skill_file" | grep -qi "use when"; then
    echo "  WARNING: description should include 'Use when...' trigger phrases"
    ((WARNINGS++))
  fi

  echo "  OK"
}

echo "=== Lyon Skills Linter ==="
echo ""

SKILL_FILES=$(find "$SKILLS_DIR" -name "SKILL.md" -type f 2>/dev/null || true)

if [ -z "$SKILL_FILES" ]; then
  echo "No SKILL.md files found in $SKILLS_DIR"
  exit 0
fi

while IFS= read -r skill; do
  lint_skill "$skill"
done <<< "$SKILL_FILES"

echo ""
echo "=== Summary ==="
echo "Errors:   $ERRORS"
echo "Warnings: $WARNINGS"

if [ "$ERRORS" -gt 0 ]; then
  echo "FAILED"
  exit 1
fi

echo "PASSED"
