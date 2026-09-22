---
name: incident-management
description: >
  Incident management practices for production infrastructure: incident metrics
  (MTBF, MTTR, MTTA, MTTF), alert severity levels (P1-P5) with per-level response
  playbooks, 24/7 on-call process design (detection, paging channels, response SLA,
  RCA), and on-call paging conditions. Use when defining incident severity, designing
  on-call rotations or escalation policies, measuring incident response performance,
  writing postmortems/RCA, or deciding whether an alert should page, mention, or stay
  silent.
license: MIT
metadata:
  author: Lyon
  version: "0.1.0"
---

# Incident Management

Incident management framework for production systems: how incidents are measured,
classified by severity, and responded to through a 24/7 on-call process.

## 1. Incident Metrics

Metrics that measure incident response capability.
**System reliability**: MTBF, MTTR / **Operational responsiveness**: MTTA, MTTF.

| Metric | Name | Measures | Signal |
|--------|------|----------|--------|
| **MTBF** | Mean Time Between Failures | Average time between *repairable* failures | Higher = more stable system (availability/stability tracking) |
| **MTTR** | Mean Time To Repair | Average time to repair a failed system and restore normal operation — includes repair **and** testing time, until fully operational | Lower = faster recovery capability |
| **MTTA** | Mean Time To Acknowledge | Average time from alert trigger to work starting on the issue | Lower = responsive team + effective alerting system |
| **MTTF** | Mean Time To Failure | Average time between *non-repairable* failures | Higher = more reliable components; estimates system available time |

**How to use them:**

- **MTTA** audits the alerting pipeline: if MTTA is high, fix alert routing/paging before
  blaming responders. Pair with the on-call SLA (see §3 — respond within 5 minutes).
- **MTTR** audits recovery tooling: runbooks, rollback automation, dashboards.
  MTTR includes verification time — "it's probably fine" is not restored.
- **MTBF** trends justify reliability investment: a dropping MTBF means recurring
  incident classes are not being eliminated by postmortem action items.
- Report these per severity level (a P4 flood should not mask P1 MTTR regressions).

## 2. Alert Severity Levels (P1–P5)

Standard severity classification for all alerts. Datadog 1-based priority aligns 1:1.

### Level definitions

| Level | Type | Definition |
|-------|------|-----------|
| 🔴 **P1 (Critical)** | Service outage | Major service down (full system failure, core API down). Immediate response required. Includes security threats (data breach, intrusion) |
| 🟠 **P2 (High)** | Degradation / partial outage | Some functionality abnormal (slow responses, elevated error rate). Fast response required |
| 🟡 **P3 (Medium)** | Warning | Errors occurred but service impact is low (e.g. high resource utilization). Needs monitoring and root-cause analysis |
| 🔵 **P4 (Low)** | Informational | No operational impact (system status, job completion). Periodic review recommended |
| ⚪ **P5 (Negligible)** | Minimal impact | Negligible or ignorable. No service impact, no action needed |

### Alert-type → severity mapping

| Level | Alert type | Examples |
|-------|-----------|----------|
| 🔴 P1 | Service outage | Core service/feature down: API 5xx surge, DB failure |
| 🔴 P1 | Security event | Intrusion detection, abnormal traffic, exploit attempts |
| 🟠 P2 | Performance degradation | Response latency, rising error rate, traffic spike |
| 🟠 P2 | Network anomaly | Major network failure, DNS issues, load balancer failure |
| 🟡 P3 | Resource limits | CPU / memory / disk / DB connection pool at threshold |
| 🟡 P3 | Deploy failure | CI/CD deploy failed or rolled back (escalate to P2 if service impact is large) |
| 🟡 P3 | Storage threshold | S3 / EBS / DB capacity shortage |
| 🔵 P4 | Advisory | Predicted issues, config change notices, routine operational events |
| 🔵 P4 | Job completion | Normal completions (CronJob success, deploy done) |
| ⚪ P5 | Negligible | Ignorable noise (unneeded log output, expected events) — no business impact |

### Response playbook per level

| Level | Response | Details |
|-------|----------|---------|
| 🔴 P1 | **Immediate response** | Page on-call by the fastest channel; start company-wide response (war room). **All required experts** (sysadmin, developers, security) join immediately. **Restore service first**, then postmortem for prevention. Channels: SMS, phone call |
| 🟠 P2 | **Fast response** | Slack mention to acknowledge; begin remediation quickly. Core (not all) functionality affected — restore that feature first. Pre-provisioned mitigations (monitoring, auto-scaling) should exist |
| 🟡 P3 | **Monitor & analyze** | Periodic checks over immediate action; predictable response. If it recurs, invest resources in root cause and prevention |
| 🔵 P4 | **Reference only** | Informational; keep watching so it doesn't escalate. Record/analyze; low priority |
| ⚪ P5 | **Ignorable** | Monitor only, no action. Record-keeping only |

**Classification rules of thumb:**

- Severity is set explicitly (a `severity` tag/label `P1`–`P5`) at the alert rule; if
  absent, fall back to alert-type mapping, then monitoring-platform priority.
- P1/P2 = pages or mentions humans. P3 and below must **never page** — protecting page
  fatigue is what keeps P1 response fast.
- When in doubt between two levels, ask: "does someone need to act *now*?" Yes at
  3 AM → P1. Yes during work hours → P2. No → P3 or lower.

## 3. On-Call Process

24/7 on-call participated in by DevOps engineers only.

### Detection & alert triggers

| Source | Trigger path |
|--------|--------------|
| Monitoring systems (Grafana, NewRelic, Datadog) | Incident detected → **Alertmanager** triggers notification |
| AWS | Incident detected → **Lambda** triggers notification |
| Slack channels | Incident pattern detected → **oncall-manager** triggers notification |
| Webhook service | Formats and dispatches messages per notification channel |

### Paging channels

SMS, phone call, email, on-call app (e.g. OpsGenie), KakaoTalk (or regional messenger) —
multiple channels so a single dead channel cannot lose a page.

### Response flow

1. Failure detected (monitoring / AWS / Slack triggers)
2. Incident → `/webhook` → notification dispatched to paging channels
3. On-call engineer **acknowledges within 5 minutes** of the page (this SLA is what MTTA measures)
4. Root cause analysis and remediation
5. After resolution: **RCA (Root Cause Analysis)** and prevention plan shared with the team

### Tooling

| Role | Tools |
|------|-------|
| Monitoring | Prometheus, Grafana, NewRelic, Datadog |
| Alert routing | Alertmanager / Lambda → `/webhook` |
| Message transform & dispatch | oncall-manager |
| Delivery | AWS (SMS/voice), messenger API (e.g. NHN Cloud KakaoTalk), OpsGenie |

> Escalation policy (secondary on-call, manager escalation on missed pages) should be
> defined as the rotation matures — review periodically.

### On-call paging conditions (what actually pages)

Only conditions implying **service-level impact on critical services** page the on-call:

| Category | Condition | Rationale |
|----------|-----------|-----------|
| Kubernetes | Critical-service ReplicaSet has **0 ready pods** | Total loss of a critical service |
| Kubernetes | Critical-service pod restart count ≥ 3 | Crash-loop signals imminent outage |
| APM | Critical-service response time > threshold sustained 5m+ (per-framework p90/p95 thresholds) | User-facing latency degradation |
| Data | Core data table integrity/state anomaly | Business-data corruption risk |
| AWS | DNS health check failure | Entry-point availability |

"Critical service" is defined by a service-criticality registry (e.g. SMR High level) —
keep the paging list tied to that registry, not ad-hoc.

### Latency paging thresholds (methodology)

- Evaluate **p90** percentile (p95 for the API gateway); never averages.
- **P2 (Slack warning)** threshold = normal p90 (production 7d average) × 1.5–2
- **P1 (page)** threshold = normal peak (7d hourly-max of 5m p90) × 1.5–3, always above P2
- Validate thresholds against real incident data as a counter-evidence check
  (n=1 incidents cannot *prove* a threshold, only falsify one).
- Set per-framework baselines (gateway/backend/frontend/mobile differ by an order of
  magnitude); add per-service tiers for services legitimately above baseline.
- Exclude operations where latency thresholds are meaningless (async consumers,
  batch runs) — keep error-rate alerts only for those.

## 4. Postmortem / RCA Standards

- Every P1, and any P2 with user impact, gets a written RCA.
- RCA answers: timeline (detect → acknowledge → mitigate → resolve), root cause,
  blast radius, what worked/what didn't, prevention action items with owners.
- Blameless: name systems and gaps, not people.
- Action items feed back into: alert thresholds (§2), paging conditions (§3),
  and the metrics review (§1 — did MTTA/MTTR actually improve?).
