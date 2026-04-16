# Observability Reference

## Grafana LGTM Stack

### Architecture Overview
```
                    ┌─────────────┐
                    │   Grafana   │  Visualization
                    └──────┬──────┘
                           │
            ┌──────────────┼──────────────┐
            │              │              │
     ┌──────┴──────┐ ┌────┴────┐ ┌──────┴──────┐
     │    Mimir    │ │  Loki   │ │   Tempo     │
     │  (Metrics)  │ │ (Logs)  │ │ (Traces)    │
     └──────┬──────┘ └────┬────┘ └──────┬──────┘
            │              │              │
            └──────────────┼──────────────┘
                           │
              ┌────────────┼────────────┐
              │            │            │
       ┌──────┴──┐  ┌─────┴────┐ ┌────┴─────┐
       │  Alloy  │  │   OTel   │ │ Promtail │
       │(Metrics)│  │Collector │ │  (Logs)  │
       └─────────┘  └──────────┘ └──────────┘
```

### Grafana Configuration

```yaml
# Datasources: Loki + Mimir + Tempo with cross-linking
datasources:
  - name: Loki
    uid: loki
    type: loki
    url: http://loki-gateway
  - name: Mimir
    uid: prom
    type: prometheus
    url: http://mimir-nginx/prometheus
    isDefault: true
  - name: Tempo
    uid: tempo
    type: tempo
    url: http://tempo-query-frontend:3100
    jsonData:
      tracesToLogsV2:
        datasourceUid: loki       # Trace -> Log correlation
      lokiSearch:
        datasourceUid: loki
      tracesToMetrics:
        datasourceUid: prom       # Trace -> Metric correlation
      serviceMap:
        datasourceUid: prom       # Service dependency map

# Deployment
persistence:
  enabled: true
  existingClaim: pvc-grafana
affinity:
  nodeAffinity:               # Pin to specific AZ for PVC
    requiredDuringSchedulingIgnoredDuringExecution:
      nodeSelectorTerms:
        - matchExpressions:
            - key: topology.kubernetes.io/zone
              operator: In
              values: ["ap-northeast-2a"]
deploymentStrategy:
  type: Recreate              # Required for PVC
securityContext:
  fsGroup: 472
  runAsUser: 472
resources:
  requests: { cpu: 500m, memory: 1Gi }
  limits: { cpu: 1, memory: 2Gi }
```

### Loki Distributed Deployment

```yaml
# Distributed mode — separate read/write/backend components
deploymentMode: Distributed

loki:
  auth_enabled: false
  schemaConfig:
    configs:
      - from: "2024-05-01"
        store: tsdb
        object_store: s3
        schema: v13
        index:
          prefix: loki_index_
          period: 24h
  compactor:
    retention_enabled: true
    retention_delete_delay: 10m
  limits_config:
    ingestion_burst_size_mb: 1024
    ingestion_rate_mb: 1024
    reject_old_samples: true
    reject_old_samples_max_age: 168h     # 7 days
    retention_period: 1y
    query_timeout: 300s
    split_queries_by_interval: 15m
  ingester:
    chunk_encoding: snappy
  tracing:
    enabled: true

# Component replicas
ingester:
  replicas: 3
querier:
  replicas: 3
queryFrontend:
  replicas: 2
queryScheduler:
  replicas: 2
distributor:
  replicas: 3
compactor:
  replicas: 1
indexGateway:
  replicas: 2

# Gateway with autoscaling
gateway:
  replicas: 2
  autoscaling:
    enabled: true
    minReplicas: 2
    maxReplicas: 5
    targetCPUUtilizationPercentage: 60
    targetMemoryUtilizationPercentage: 80

# Caching
resultsCache:
  enabled: true
chunksCache:
  enabled: true
  allocatedMemory: 2048
```

### OpenTelemetry Collection Pipeline

```
┌──────────┐     ┌──────────────┐     ┌───────────┐
│ App Pods │────▸│ OTel Collector│────▸│ Tempo     │ (traces)
│ (SDK)    │     │ (DaemonSet)  │────▸│ Loki      │ (logs)
└──────────┘     └──────────────┘────▸│ Mimir     │ (metrics)
                                      └───────────┘
```

**Deployment modes:**
- **DaemonSet**: Node-level collection (logs, host metrics)
- **Deployment**: Cluster-level receivers (OTLP, Zipkin endpoints)

**Auto-instrumentation:**
```yaml
# OTel Operator auto-instrumentation
apiVersion: opentelemetry.io/v1alpha1
kind: Instrumentation
metadata:
  name: otlp-instrumentation
spec:
  exporter:
    endpoint: http://otel-collector:4317
  propagators:
    - tracecontext
    - baggage
  # Per-language injection
  java:
    image: ghcr.io/open-telemetry/opentelemetry-operator/autoinstrumentation-java:latest
  nodejs:
    image: ghcr.io/open-telemetry/opentelemetry-operator/autoinstrumentation-nodejs:latest
  python:
    image: ghcr.io/open-telemetry/opentelemetry-operator/autoinstrumentation-python:latest
```

### Deployment: Umbrella Chart Pattern
```bash
# Reference: github.com/yieon-lyon/lgtm-sample
helm install lgtm ./charts/lgtm \
  --namespace monitoring \
  --create-namespace \
  --values values-{env}.yaml
```

### LogQL Quick Reference
```logql
# Error rate by service
sum(rate({namespace="production"} |= "error" [5m])) by (service)

# Latency from structured logs
{service="api"} | json | latency > 500ms

# Top 10 error messages
topk(10, sum(count_over_time({level="error"}[1h])) by (message))
```

### PromQL Patterns for SRE
```promql
# SLI: Availability (success rate)
sum(rate(http_requests_total{code=~"2.."}[5m]))
/
sum(rate(http_requests_total[5m]))

# SLI: Latency P99
histogram_quantile(0.99, sum(rate(http_request_duration_seconds_bucket[5m])) by (le))

# Error budget burn rate
1 - (
  sum(rate(http_requests_total{code=~"5.."}[1h]))
  /
  sum(rate(http_requests_total[1h]))
) / (1 - 0.999)
```

## Prometheus HA Comparison

| Feature | Thanos | Mimir |
|---------|--------|-------|
| Architecture | Sidecar + Querier + Store | Monolithic or Microservices |
| Long-term Storage | S3/GCS (object store) | S3/GCS (object store) |
| Query Federation | Global view via Store API | Tenant-isolated queries |
| Operational Complexity | Moderate (many components) | Low (single binary mode) |
| **Recommendation** | Existing Prometheus setups | Greenfield deployments |

## Datadog Integration via Terraform

```hcl
module "datadog" {
  source = "../../modules/aws/datadog"

  environment     = var.environment
  account_id      = data.aws_caller_identity.current.account_id
  datadog_api_key = var.datadog_api_key
  datadog_app_key = var.datadog_app_key

  enable_aws_integration = true
  enable_log_forwarder   = true
}
```

## AWS CloudWatch Alarm Pattern

```hcl
# CloudWatch Alarm -> SNS -> Chatbot -> Slack
module "cloudwatch_alarm" {
  source = "../../modules/aws/cloudwatch-alarm"

  alarm_name          = "rds-cpu-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 3
  metric_name         = "CPUUtilization"
  namespace           = "AWS/RDS"
  period              = 300
  threshold           = 80
  alarm_actions       = [module.chatbot_slack.sns_topic_arn]
}
```

## Monitoring Strategy by Layer

| Layer | Tool | Metrics |
|-------|------|---------|
| Infrastructure | CloudWatch + Grafana | EC2, RDS, ElastiCache, AmazonMQ |
| Kubernetes | Prometheus/Mimir + Grafana | Node, Pod, Container, Karpenter |
| Network | Cilium Hubble + Grafana | DNS, drops, flows, TCP, HTTP |
| Application | Datadog APM / Tempo | Traces, Error rates, Latency |
| Logs | Loki / Datadog Logs | Structured logs, Error patterns |
| Security | Tetragon + Grafana | Process exec, file access, privilege escalation |
| Business | Custom Grafana dashboards | SLIs, SLOs, Error budgets |

## Alert Rules

```yaml
# Kubernetes health alert rules (ConfigMap)
groups:
  - name: kubernetes-health
    rules:
      - alert: KubernetesPodCrashLooping
        expr: rate(kube_pod_container_status_restarts_total[15m]) > 0
        for: 5m
      - alert: KubernetesHPAMaxReplicasReached
        expr: kube_horizontalpodautoscaler_status_current_replicas == kube_horizontalpodautoscaler_spec_max_replicas
        for: 10m

  - name: cilium-health
    rules:
      - alert: CiliumAgentUnreachable
        expr: cilium_unreachable_nodes > 0
        for: 5m
      - alert: CiliumPolicyDenied
        expr: rate(cilium_drop_count_total{reason="POLICY_DENIED"}[5m]) > 10
        for: 5m
```
