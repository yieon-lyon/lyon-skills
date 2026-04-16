# EKS Operations Reference

## Cluster Inventory

| Cluster | Account | Env | K8s Ver | Purpose |
|---------|---------|-----|---------|---------|
| {company}-{env-1} | {account-a} | {env-1} | 1.33 | Lower environment |
| {company}-{env-2} | {account-a} | {env-2} | 1.33 | Lower environment |
| {company}-{env-N} | {account-a} | {env-N} | 1.33 | Lower environment |
| {company}-{env-1} | {account-b} | {env-1} | 1.33 | Pre-production |
| {company}-{env-N} | {account-b} | {env-N} | 1.33 | Live traffic |

## Karpenter Architecture

### Helm Chart: Service-to-NodePool Mapping

Karpenter resources are generated from a Helm chart that maps services to NodePool/EC2NodeClass pairs.
Base definitions + environment overlays are merged at render time.

```
autoscaling/karpenter/
├── base/
│   ├── charts/nodegroups/          # Helm chart for NodePool generation
│   │   ├── Chart.yaml
│   │   └── templates/resources.yaml
│   ├── nodegroups.yaml             # Base nodegroup definitions (values)
│   └── crds/                       # CRDs per Karpenter version
└── overlays/
    ├── prod/                       # Production overrides
    ├── {env-1}/, {env-2}/, ... /
    └── patches/                    # Environment-specific patches
```

### Base NodeGroup Definitions

```yaml
# nodegroups.yaml — base values for Helm chart
baseNodeGroups:
  - name: standard-services
    services: ["account-svc", "ad-svc", "payment-svc", ...]  # API services
    storage:
      volumeSize: 20Gi

  - name: default
    services: ["default"]
    storage:
      volumeSize: 30Gi

  - name: cicd
    services: ["cicd"]
    storage:
      volumeSize: 20Gi

  - name: cron
    services: ["cron"]
    storage:
      volumeSize: 30Gi

  - name: monitoring
    services: ["monitoring"]
    storage:
      volumeSize: 20Gi

  - name: system-critical
    services: ["system-critical"]
    storage:
      volumeSize: 20Gi

# Base EC2NodeClass template
ec2nodeclass:
  amiSelectorTerms:
    - alias: al2023@latest
  blockDeviceMappings:
    - deviceName: /dev/xvda
      ebs:
        volumeType: gp3
        deleteOnTermination: true
  tags:
    Team: devops

# Base NodePool template
nodepool:
  disruption:
    consolidateAfter: 5m
    consolidationPolicy: WhenEmptyOrUnderutilized
  template:
    spec:
      expireAfter: Never
```

### Helm Template: Merge Strategy

The chart template merges base + env configs with a clear priority:

1. Iterate `baseNodeGroups`, overlay `envNodeGroups` where names match
2. Add env-only nodegroups not present in base
3. For each service in a merged group, generate paired **EC2NodeClass** + **NodePool**

```yaml
# resources.yaml — key generation logic
{{- range $allNodeGroups }}
{{- range .services }}
---
apiVersion: karpenter.k8s.aws/v1
kind: EC2NodeClass
metadata:
  name: {{ . }}
spec:
  role: {{ $.Values.ec2nodeclass.role }}
  amiSelectorTerms: ...
  blockDeviceMappings:
    - deviceName: /dev/xvda
      ebs:
        volumeSize: {{ $nodegroup.storage.volumeSize | default "20Gi" }}
  tags:
    Service: {{ . }}
---
apiVersion: karpenter.sh/v1
kind: NodePool
metadata:
  name: {{ . }}
spec:
  disruption: ...
  template:
    spec:
      nodeClassRef:
        name: {{ . }}
      requirements:
        # env-level requirements override base by key
        {{ mergedRequirements }}
        - key: eks.amazonaws.com/nodegroup
          operator: In
          values: ["{{ . }}"]
      taints: ...        # Service-specific taints
  weight: 10
{{- end }}
{{- end }}
```

### Environment Overlay Examples

```yaml
# overlays/prod/patches/patch-nodegroups.yaml
envNodeGroups:
  - name: standard-services
    requirements:
      - key: karpenter.sh/capacity-type
        operator: In
        values: ["on-demand"]        # Production: on-demand only
      - key: topology.kubernetes.io/zone
        operator: In
        values: ["ap-northeast-2a", "ap-northeast-2c"]

  - name: gpu                          # Production-only nodegroup
    services: ["gpu"]
    storage:
      volumeSize: 50Gi
    requirements:
      - key: node.kubernetes.io/instance-type
        operator: In
        values: ["g4dn.xlarge", "g4dn.2xlarge"]
      - key: karpenter.sh/capacity-type
        operator: In
        values: ["on-demand"]
    taints:
      - key: nvidia.com/gpu
        effect: NoSchedule
    limits:
      cpu: "8"
      nvidia.com/gpu: "2"
```

### NodeGroup Service Categories

| Group | Instance Category | Taint | Use Case |
|-------|-------------------|-------|----------|
| standard-services | m (general) | `system-type: service` | API microservices |
| cpu-optimized | c (compute) | `system-type: service` | Gateways, heavy compute |
| monitoring | r (memory) | `system-type: monitoring` | Prometheus, Loki, Grafana |
| cron | c (compute) | `system-type: cron` | Scheduled jobs, batch |
| cicd | c/m | `system-type: cicd` | CI/CD runners |
| gpu | g4dn | `nvidia.com/gpu` | ML inference |
| system-critical | m (general) | (none) | CoreDNS, Karpenter, critical |

### Karpenter Version History

| Version | API | Key Changes |
|---------|-----|-------------|
| 0.36.2 | v1beta1 | Initial adoption |
| 0.37.7 | v1beta1 | Webhook support added |
| 1.0.7 | v1 | GA release, API stabilization |
| 1.6.0 | v1 | Current — improved consolidation |

## Cluster Upgrade Procedure

### Pre-flight Checklist
- [ ] Review EKS release notes for target version
- [ ] Check addon compatibility matrix (VPC CNI, CoreDNS, kube-proxy)
- [ ] Verify Karpenter version supports target K8s version
- [ ] Test upgrade in lowest environment first
- [ ] Notify team of maintenance window

### Upgrade Order
1. **Control Plane**: Update `cluster_version` in Terraform
2. **Addons**: Update addon versions to match K8s version
3. **Karpenter**: Update Karpenter chart version if needed
4. **NodePools**: Trigger node rotation via Karpenter drift
5. **Managed Node Groups**: Update AMI / launch template

### Post-upgrade Validation
```bash
# Check node versions
kubectl get nodes -o wide

# Verify all pods running
kubectl get pods -A --field-selector=status.phase!=Running

# Check Karpenter logs
kubectl logs -n kube-system -l app.kubernetes.io/name=karpenter -c controller --tail=50

# Verify metrics pipeline
kubectl port-forward -n monitoring svc/grafana 3000:3000
```

## Autoscaling Decision Matrix

| Scenario | Solution |
|----------|----------|
| General workloads, cost-optimized | Karpenter with spot + consolidation |
| System/infra pods (karpenter, monitoring) | Managed Node Groups (on-demand) |
| GPU/ML workloads | Karpenter with g4dn, on-demand only |
| Stateful workloads (databases) | Managed Node Groups with EBS |
| CI/CD runners | Karpenter with maxPods kubelet config |
| Production APIs | Karpenter with on-demand, AZ-constrained |

## Troubleshooting Quick Reference

| Symptom | Check |
|---------|-------|
| Pods pending | `kubectl describe pod` -> Events, NodePool limits, subnet capacity |
| Node not joining | EC2 console -> instance logs, security groups, IAM role |
| Karpenter not scaling | Controller logs, NodePool status, EC2 capacity |
| CNI errors | VPC CNI version, prefix delegation config, IP exhaustion |
| Consolidation stuck | Check PDB, pod anti-affinity, `do-not-disrupt` annotations |
