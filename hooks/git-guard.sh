#!/usr/bin/env bash
set -euo pipefail

command -v python3 >/dev/null 2>&1 || exit 0

python3 -I -c '
import json, re, sys

try:
    data = json.load(sys.stdin)
except Exception:
    sys.exit(0)

cmd = data.get("tool_input", {}).get("command", "") or ""

pattern = re.compile(
    r"\bgit\b[^|;&]*\b(commit|push|merge|rebase|cherry-pick|am)\b"
    r"|\bgit\s+(checkout\s+-b|switch\s+-c)\b"
    r"|\bgit\s+branch\s+(?!--list\b|-l\b|-a\b|-r\b|-v+\b|--show-current\b)\S"
    r"|\bgit\s+tag\s+(?!--list\b|-l\b)\S"
    r"|\bgit\s+reset\b"
    r"|\bgit\s+stash\s+(drop|pop|clear)\b"
    r"|\bgh\s+pr\s+(create|merge|close)\b"
)

if pattern.search(cmd):
    print(json.dumps({
        "hookSpecificOutput": {
            "hookEventName": "PreToolUse",
            "permissionDecision": "ask",
            "permissionDecisionReason": (
                "git-discipline: state-changing git command intercepted. "
                "Requires an explicit user instruction in the current conversation "
                "(read the git-discipline skill before proceeding)."
            ),
        }
    }))
'
