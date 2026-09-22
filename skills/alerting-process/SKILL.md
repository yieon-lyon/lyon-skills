---
name: alerting-process
description: >
  Alert notification pipeline design: an alert-manager middleware that normalizes
  Grafana alerts and Datadog monitor events into one model, routes to Slack channels
  by severity/env/service, threads firing→recovery lifecycles, coalesces re-fires,
  escalates long-running production alerts, and separates paging (on-call manager)
  from notification delivery. Includes Grafana/Datadog webhook API contracts (labels,
  tags, payload variables) and latency alert threshold assessment. Use when designing
  alert routing, integrating Grafana/Datadog webhooks, defining Slack alert channels,
  setting severity-based mention policies, or tuning latency alert thresholds.
license: MIT
metadata:
  author: Lyon
  version: "0.1.0"
---

# Alerting Process

Design of the alert notification pipeline: a self-hosted **alert-manager middleware**
that receives **Grafana alerts** and **Datadog monitor events**, normalizes them into a
single common model, renders one Slack message template, and groups the whole
firing→recovery lifecycle into a thread.

**Separation of concerns**: the **on-call manager** owns *urgent paging*
(phone/SMS/messenger escalation); the **alert manager** owns *alert processing,
delivery, and operations*. Never mix the two — paging must stay simple and reliable
while notification logic can be rich.

## 1. Service Summary

- **Host**: `alert.ops.{company}.com` (shares an ALB with the on-call manager, path-separated)
- **Endpoints**: `/grafana`, `/datadog`, `/slack/events`, `/slack/actions`, `/slack/commands`
- **State**: dedicated Redis — fingerprint-based **distributed lock** so multi-replica
  deployments never double-post; threads survive pod restarts
- **Security**: Slack request **signature verification always enforced** (cannot be disabled)

## 2. Severity (P1–P5)

Follows the org-standard Alert Severity Levels (see the `incident-management` skill),
aligned 1:1 with Datadog's 1-based priority.

| Level | Icon | Meaning | Mention policy |
|-------|------|---------|----------------|
| **P1** Critical | 🔴 | Service outage / security threat | Immediate sre-oncall mention |
| **P2** High | 🟠 | Degradation / network anomaly | Mention after 3 repeats |
| **P3** Medium | 🟡 | Warning / resource limits / deploy failure | No mention |
| **P4** Low | 🔵 | Informational / job completion | No mention |
| **P5** Negligible | ⚪ | Ignorable | No mention |

**Severity resolution order**: `severity` tag/label (`P1`–`P5`) → `alert_type` mapping →
Datadog `priority`. Explicit beats inferred.

## 3. Channel Routing

Priority: `slack_channel label > service_rules > pack_channel > severity_rules > env_channel > default`

| env | Channel |
|-----|---------|
| production | `#alert-ops` (P1·P2) / `#alert-ops-low` (P3 and below) |
| sep-production | `#sep-alert-ops` |
| staging | `#alert-ops-staging` |
| sep-staging | `#sep-alert-ops-staging` |
| qa | `#alert-ops-qa` |
| dev | `#alert-ops-dev` |
| platform | `#alert-devops-platform` |

- **env derivation**: `kube_cluster_name` (kubernetes/standard packs) or `env` tag
  (host/rds/rum/apm packs)
- **env normalization**: `qa-*`→qa, `dev-*`→dev, `local*`/`development`→dev
- RUM production splits by `service` into `#alert-ops-frontend` / `#alert-ops-mobile`

**Design principles**: production P1/P2 goes to a high-signal channel; P3-and-below
noise is quarantined to a `-low` channel so the primary channel stays actionable.
Every env gets its own channel — cross-env mixing kills signal.

## 4. Alert Lifecycle (threading model)

1. **First firing**: post a **parent message** to the routed channel — severity color,
   fields (Env/Cluster/Namespace/Pod/NodeClaim, etc.), graph snapshot, action buttons
2. **Re-fires**: accumulate as **thread replies** (`재발생 #N`) — coalesced to at most
   **1 reply per minute per alert** to prevent flooding (the count stays exact)
3. **Recovery (resolved)**: ✅ recovery reply in the thread + parent message turns green

Grouping keys: Grafana `fingerprint`; Datadog `alert_cycle_key` (constant for one
trigger→recover cycle; a re-trigger after recovery gets a new key → new parent message).

## 5. Message Action Buttons

Placed in priority order (Slack shows 5; the rest collapse into +N):

| Button | Action | Shown when |
|--------|--------|-----------|
| Investigate With Bits | Trigger a Bits AI investigation via API + post the investigation link in-thread (idempotent per event) | Datadog source, firing only |
| DevOps Agent | Convert the alert into an incident event and send to the DevOps Agent webhook (HMAC-signed, idempotent) | firing & recovered |
| 🚨 Declare Incident / 🗂 Create case / ⚙️ Run workflow | Slack modal → Datadog API, linked to the source monitor | Datadog source, firing & recovered |
| 🔕 Mute monitor | Mute 1h/4h/1d/7d (+ unmute button) | Datadog source, firing only |
| 🔗 Event URL | Datadog event page link | firing only |

## 6. Sustained-Alert Escalation

Production **P1/P2** alerts firing for **3+ hours** get an SRE subteam mention in the
alert thread requesting acknowledgment — with a **6-hour cooldown, once per cluster**.
This catches alerts that were seen but silently dropped.

## 7. Alert Reports

Aggregate reports of currently-firing alerts are delegated to a separate
**report-manager**: `/report alert` in Slack (all envs: `/report alert all`,
one env: `/report alert qa`).

## 8. Slack-Sourced Alert Conditions (on-call mention)

The pipeline also *watches Slack itself* for anomaly patterns:

| Category | Condition | Purpose |
|----------|-----------|---------|
| SlackShare | ≥10 identical messages within 10 minutes | Detect abnormal message floods; forward to a triage channel |
| SlackThread | Specific keyword detected (e.g. topology/availability keywords) | Track availability-degrading messages; mention in the message's thread |

## 9. Webhook API Contracts

### Grafana → `/grafana`

- **Method**: `POST`, `Content-Type: application/json`
- **Auth**: query `apiKey=...` or header `API-Key: ...`
- Accepts the **standard Grafana Alerting webhook** (`alerts[]`) as-is — no body
  template; behavior is controlled entirely by **alert rule labels/annotations**.

**Required label**

| Label | Value | Effect |
|-------|-------|--------|
| `alert-manager` | `"true"` | Alerts without it are **ignored** (`processed: 0`) — one contact point can safely carry many rules |

**Recommended labels/annotations**

| Kind | Key | Purpose |
|------|-----|---------|
| label | `severity` | `P1`–`P5` explicit (else `alert_type` default mapping) |
| label | `slack_channel` | Explicit channel (highest routing priority) |
| label | `kube_cluster_name` or `env` | env derivation for routing |
| label | `alert_type` | Message Type field + severity default mapping (falls back to `alertname`) |
| label | `namespace` / `pod` (or `kube_replica_set`) / `cluster` / `karpenter.sh/nodeclaim` | Message fields |
| label | `infrastructure` | `aws` → show `Series` label; `mongodb` → show `cl_name` label |
| annotation | `summary` / `description` | Message title / body |
| annotation | `deploy_link` / `log_url` | Links in the message |

**Responses**: `200 {"received":1,"processed":1}` · `200 {"received":1,"processed":0}`
(label missing → ignored) · `401` invalid api key · `400` invalid payload · `405` bad method.

### Datadog → `/datadog`

- **Method**: `POST`, `Content-Type: application/json`
- **Auth**: header `API-Key: <datadog access token>` or query `apiKey`
- Configure a Datadog monitor **Webhook Integration** (`@webhook-alert-manager`) whose
  payload uses Datadog `$VARIABLE` builtins. **`{{tag.name}}` template variables are NOT
  substituted in webhook payloads — put all routing/severity info into `$TAGS`.**

```json
{
  "id": "$ID",
  "alert_cycle_key": "$ALERT_CYCLE_KEY",
  "alert_id": "$ALERT_ID",
  "alert_transition": "$ALERT_TRANSITION",
  "alert_type": "$ALERT_TYPE",
  "alert_priority": "$ALERT_PRIORITY",
  "priority": "$PRIORITY",
  "alert_title": "$ALERT_TITLE",
  "title": "$EVENT_TITLE",
  "body": "$TEXT_ONLY_MSG",
  "alert_status": "$ALERT_STATUS",
  "alert_query": "$ALERT_QUERY",
  "alert_scope": "$ALERT_SCOPE",
  "alert_metric": "$ALERT_METRIC",
  "metric_namespace": "$METRIC_NAMESPACE",
  "hostname": "$HOSTNAME",
  "org_name": "$ORG_NAME",
  "org_id": "$ORG_ID",
  "last_updated": "$LAST_UPDATED",
  "link": "$LINK",
  "snapshot": "$SNAPSHOT",
  "tags": "$TAGS"
}
```

**Key fields**

| Field | Purpose |
|-------|---------|
| `alert_cycle_key` | **Thread grouping key** — constant across one trigger→recover cycle; new value after recovery → new parent message |
| `alert_id` | Monitor ID — used by Mute/Incident/Case/Workflow buttons (extracted from `link` `/monitors/<id>` if empty) |
| `alert_transition` | State transition — `Recovered*` → thread recovery (✅); otherwise firing |
| `id` / `last_updated` | Event ID / epoch millis — required for the Bits investigation button (button hidden without them) |
| `snapshot` | Graph image URL, attached to the parent message (if Slack rejects it, post without the image — never lose the alert) |
| `tags` | Comma-separated tags — the source of routing / severity / field rendering |

**Monitor tag → behavior mapping** (parsed from `$TAGS`)

| Tag | Use |
|-----|-----|
| `monitor_pack` (`kubernetes`/`host`/`rds`/`rum`/`apm`) or an integration tag | Message Type + env derivation strategy |
| `kube_cluster_name` (or `cluster_name`) / `env` | Channel routing |
| `severity` | `P1`–`P5` explicit (highest priority); else `alert_type` → `$ALERT_PRIORITY` |
| `service` | RUM production frontend/mobile channel split |
| `owner` / `team` | Mention target (if present) |
| `kube_namespace` / `kube_replica_set` / `karpenter.sh/nodeclaim` | Message fields (Namespace/Pod/NodeClaim) |

**Title cleanup**: Datadog's `[Triggered] [P2]`-style prefixes are stripped; the
alert manager renders severity/state itself.

**Responses**: `200 {"received":1,"processed":1}` · `401` · `400` · `405`.

## 10. Latency Alert Threshold Assessment

Method for setting latency alert thresholds per framework/service:

- Evaluate **p90** (p95 only for the API gateway); never averages.
- **P2 (Slack warning)** = normal p90 (production 7d average) × 1.5–2
- **P1 (on-call page)** = normal peak (7d hourly-max of 5m p90) × 1.5–3, strictly above P2
- Real incident data is used as a **falsification check** (n=1 can't validate, only refute):
  the threshold must have fired at the incident's epicenter values and stayed silent at
  normal propagation values.
- Structure: a **common baseline per framework op** (backend frameworks ≈ 0.2s; SSR/web
  ≈ 0.3s; BFF/mobile ≈ 0.7–1.0s; gateway p95 ≈ 0.2/0.5) + **per-service tiers** for
  services legitimately above baseline (their measured p90 × margin).
- **Exclusions**: async consumers (celery/kafka) — latency thresholds unfit, keep
  error-rate only; ops with no data in any env — remove the op entirely.

## 11. Design Principles (checklist for new alert integrations)

- [ ] One normalization layer — every source (Grafana, Datadog, future) converges on one
      common model and one message template
- [ ] Explicit opt-in (`alert-manager=true` label / dedicated webhook) — never process by default
- [ ] Idempotency everywhere: distributed lock on fingerprint, idempotent buttons,
      HMAC-signed side effects
- [ ] Thread the lifecycle; coalesce re-fires; always confirm recovery visually
- [ ] Route by severity **and** env; quarantine low-severity noise
- [ ] Mentions are earned: P1 immediately, P2 on repetition, nothing else
- [ ] Escalate sustained production alerts with a cooldown
- [ ] Degrade gracefully (post without a snapshot rather than dropping the alert)
- [ ] Paging (on-call manager) and notification (alert manager) stay separate services
