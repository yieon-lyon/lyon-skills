# Cilium & Network Security Reference

## Cilium Overview

Cilium replaces kube-proxy with eBPF-based networking, providing L3/L4/L7 network policies,
observability via Hubble, and runtime security via Tetragon.

### Stack Components

| Component | Version | Purpose |
|-----------|---------|---------|
| Cilium | v1.18.0 | eBPF-based CNI, network policy, kube-proxy replacement |
| Tetragon | v1.5.0 | Runtime security observability (eBPF) |
| Hubble | (integrated) | Network flow observability |

## Cilium Configuration

```yaml
# Core settings
kubeProxyReplacement: true        # Replace kube-proxy entirely
priorityClassName: system-cluster-critical

# CNI: AWS VPC CNI chaining mode
cni:
  chainingMode: aws-cni
  chainingTarget: aws-cni
  exclusive: false

# Routing: native (no overlay)
routingMode: native
enableIPv4Masquerade: false
enableIPv6Masquerade: false
endpointRoutes:
  enabled: false

# Protocol
ipv4:
  enabled: true
ipv6:
  enabled: false

# L7 proxy
l7Proxy: false                    # Disable if not using L7 policies

# DNS
dnsProxy:
  enableTransparentMode: false

# Resources
resources:
  limits: { cpu: 250m, memory: 512Mi }
  requests: { cpu: 250m, memory: 512Mi }

updateStrategy:
  rollingUpdate:
    maxUnavailable: "10%"

# Operator
operator:
  replicas: 3
  prometheus:
    enabled: true
```

## Hubble Observability

```yaml
hubble:
  enabled: true
  metrics:
    enabled:
      - dns:query;ignoreAAAA      # DNS query metrics
      - drop                       # Packet drop reasons
      - flow                       # Network flow metrics
      - icmp                       # ICMP metrics
      - port-distribution          # Port usage distribution
      - tcp                        # TCP connection metrics
      - kafka                      # Kafka protocol metrics
      - httpV2                     # HTTP/2 request metrics
    enableOpenMetrics: true

  # UI and relay (enable as needed)
  relay:
    enabled: false                # Enable for flow inspection
  ui:
    enabled: false                # Enable for visual network map
```

## Tetragon Runtime Security

```yaml
enabled: true

tetragon:
  enabled: true
  exportAllowList: |-
    {"event_set":["PROCESS_EXEC", "PROCESS_EXIT", "PROCESS_KPROBE", "PROCESS_UPROBE", "PROCESS_TRACEPOINT", "PROCESS_LSM"]}
    {"namespace":["{app-namespaces}"]}
  exportDenyList: |-
    {"health_check":true}
    {"namespace":["", "cilium", "kube-system", "monitoring", "argocd", "cert-manager", "kube-public", "kube-node-lease", "argo-rollouts"]}
  prometheus:
    enabled: true

updateStrategy:
  rollingUpdate:
    maxUnavailable: "20%"

priorityClassName: system-cluster-critical

tolerations:
  - operator: Exists              # Run on ALL nodes
```

## Security Policies (TracingPolicy)

### Practical Detection Rules

| Policy | Detection Target |
|--------|-----------------|
| `crypto-mining-detection` | Known mining binaries and pool connections |
| `sensitive-file-access` | Read/write to `/etc/shadow`, `/etc/passwd`, keys |
| `container-escape-detection` | Namespace manipulation, mount escape attempts |
| `privilege-escalation-detection` | setuid/setgid, capability changes |
| `reverse-shell-detection` | Suspicious network + shell combinations |
| `binary-whitelist` | Execution of non-whitelisted binaries |
| `data-exfiltration-prevention` | Large outbound data transfers to external IPs |

### Example: Crypto Mining Detection
```yaml
apiVersion: cilium.io/v1alpha1
kind: TracingPolicy
metadata:
  name: crypto-mining-detection
spec:
  kprobes:
    - call: "sys_execve"
      args:
        - index: 0
          type: "string"
      selectors:
        - matchArgs:
            - index: 0
              operator: "In"
              values:
                - "xmrig"
                - "minerd"
                - "cpuminer"
                - "ethminer"
```

### Example: Sensitive File Access
```yaml
apiVersion: cilium.io/v1alpha1
kind: TracingPolicy
metadata:
  name: sensitive-file-access
spec:
  kprobes:
    - call: "fd_install"
      args:
        - index: 1
          type: "file"
      selectors:
        - matchArgs:
            - index: 1
              operator: "Prefix"
              values:
                - "/etc/shadow"
                - "/etc/passwd"
                - "/root/.ssh"
                - "/var/run/secrets/kubernetes.io"
```

## Directory Structure

```
network/cilium/
├── base/
│   ├── cilium.yaml                 # Cilium Helm values
│   ├── tetragon.yaml               # Tetragon Helm values
│   ├── alerts.yaml                 # Prometheus alert rules
│   ├── allow-policy.yaml           # Default allow policies
│   ├── crds/                       # CiliumLocalRedirectPolicy
│   └── policies/
│       ├── cilium/                 # Network policies
│       │   └── allow-policy.yaml
│       └── tetragon/               # Runtime security policies
│           ├── practical/          # Production-ready detection rules
│           ├── host-changes/       # Kernel module monitoring
│           ├── process-exec/       # Process execution tracking
│           ├── process-credentials/# Credential change monitoring
│           ├── cves/               # CVE-specific detection
│           └── policylibrary/      # Reference policy library
└── overlays/
    ├── prod/                       # ECR image overrides
    ├── {env-1}/, {env-2}/, ... /
    └── patches/
```

## Operational Patterns

### AWS CNI + Cilium Chaining
- AWS VPC CNI handles pod IP assignment (IPAM)
- Cilium handles network policy enforcement and observability
- No overlay network — native VPC routing

### Feature Toggles by Environment

| Feature | Lower Envs | Pre-prod | Production |
|---------|------------|----------|------------|
| kubeProxyReplacement | true | true | true |
| Hubble metrics | true | true | true |
| Hubble UI | true | true | false |
| Tetragon | false | true | true |
| L7 proxy | false | false | false |
| Runtime policies | false | partial | full |

### Prometheus Integration
- Cilium agent exports metrics on `/metrics`
- Hubble metrics: DNS, drops, flows, TCP, HTTP
- Tetragon: process exec events, policy violations
- Alert rules for agent health, policy denials, unreachable nodes
