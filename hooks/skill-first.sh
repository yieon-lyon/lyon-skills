#!/usr/bin/env bash
cat <<'EOF'
lyon-skills plugin — MANDATORY: invoke the matching skill with the Skill tool BEFORE acting, never from memory of its content.
- Terraform / EKS / Karpenter / Cilium / ArgoCD / observability work -> skill: lyon
- Incident severity, on-call, paging, RCA -> skill: incident-management
- Alert routing, Grafana/Datadog webhooks, Slack alert channels -> skill: alerting-process
- ANY state-changing git command (branch, commit, push, tag, merge, rebase, PR) -> skill: git-discipline. Forbidden without an explicit user instruction in the current conversation.
- Plugin / marketplace management -> skill: skill-manager
Respond in Korean for answers, questions, and progress updates.
EOF
