# EKS Operations Reference

## Cluster Inventory

| Cluster | Account | Env | K8s Ver | Purpose |
|---------|---------|-----|---------|---------|
| {company}-{env-1} | {account-a} | {env-1} | 1.33 | Lower environment |
| {company}-{env-2} | {account-a} | {env-2} | 1.33 | Lower environment |
| {company}-{env-N} | {account-a} | {env-N} | 1.33 | Lower environment |
| {company}-{env-1} | {account-b} | {env-1} | 1.33 | Pre-production |
| {company}-{env-N} | {account-b} | {env-N} | 1.33 | Live traffic |

## Third-Party Deployment Methods (kubernetes-thirdparty)

All cluster add-ons live in a single `kubernetes-thirdparty` repository, organized by
domain (`autoscaling/`, `cicd/`, `cluster/`, `networking/`, `observability/`, `security/`,
`ai/`, `automation/`, `testing/`). Three deployment methods coexist:

> **Direction: kustomize-first.** When adding or refactoring a component, prefer
> **pure kustomize**, then **helm + kustomize** (kustomize `helmCharts` generator) when an
> upstream chart is the only sane distribution, and keep **pure helm** only for simple,
> low-touch components. Raw `helm upgrade --install` on upper environments is what we are
> migrating away from — everything should converge on `kustomize build | kubectl apply`
> (or ArgoCD) with declarative, per-env overlays in Git.

### Method comparison

| Method | When to use | State lives in | Examples |
|--------|-------------|----------------|----------|
| **kustomize only** (preferred) | We own the manifests, or upstream ships plain YAML | `base/` + `overlays/{env}/` | argocd, crowdstrike, cert-manager, kubernetes-event-exporter |
| **helm + kustomize** (preferred for upstream charts) | Upstream distributes a Helm chart but we want declarative overlays, image mirroring, and patches | `base/` values + `overlays/{env}/kustomization.yaml` with `helmCharts` | karpenter (nodegroups), cilium, tetragon, loki, mimir, tempo, grafana, prometheus, promtail, datadog, clickhouse, kubescape, github-actions runner, nvidia gpu-operator |
| **pure helm** | Simple components with a values file per env, infrequent changes | `{env}-values.yaml` at component root + README commands | metrics-server, reloader, reflector, keda, vector, external-dns, aws-load-balancer-controller, kong, spotguard, argo-rollouts |

### 1. Pure kustomize (preferred)

Standard base/overlay layout; env differences are patches only:

```
{component}/
├── base/
│   ├── kustomization.yaml
│   └── *.yaml                  # deployment, rbac, service, ...
└── overlays/
    └── {env}/
        ├── kustomization.yaml  # resources: ../../base + patches
        └── patches/
```

```bash
kustomize build ./overlays/{env} | kubectl apply -f -
```

### 2. Helm + kustomize (kustomize `helmCharts` generator)

Used when upstream only ships a Helm chart. The chart is rendered *through* kustomize,
so we still get overlays, strategic-merge patches, and ECR image mirroring on top of
chart values:

```yaml
# overlays/{env}/kustomization.yaml (e.g. Loki)
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

namespace: monitoring

images:                                    # mirror upstream images to ECR
  - name: memcached
    newName: {account}.dkr.ecr.ap-northeast-2.amazonaws.com/grafana/memcached
    newTag: 1.6.38-alpine

helmCharts:
  - name: loki
    repo: "https://grafana.github.io/helm-charts"
    version: "6.55.0"
    releaseName: loki
    namespace: monitoring
    includeCRDs: false
    valuesFile: ../../base/loki.yaml       # shared base values
    additionalValuesFiles:
      - patches/patch-loki.yaml            # env-specific values layered on top

patches:                                   # taints/nodeSelector & co. as kustomize patches
  - target: { kind: StatefulSet, name: ".*" }
    path: ../../base/patches/patch-statefulset.yaml
  - target: { kind: Deployment, name: ".*" }
    path: ../../base/patches/patch-deployment.yaml
```

```bash
kustomize build ./overlays/{env} --enable-helm --load-restrictor=LoadRestrictionsNone | kubectl apply -f -
```

Conventions:
- **Base values** (`base/{chart}.yaml`) hold cluster-agnostic settings; **env values**
  (`overlays/{env}/patches/patch-*.yaml`) layer on top via `additionalValuesFiles`.
- **Image mirroring**: upstream images are re-pointed to ECR via `images:` transformers.
- **Node placement** (taints/nodeSelector) is applied as kustomize patches on rendered
  output — not scattered through chart values — so the pattern is identical across charts.
- Local charts use `helmGlobals.chartHome` (e.g. karpenter's `nodegroups` chart).

### 3. Pure helm (legacy / simple components)

Per-env values files at the component root, applied with explicit helm commands from the
README. Acceptable for low-churn components; do not adopt for new complex components.

```bash
helm repo add metrics-server https://kubernetes-sigs.github.io/metrics-server/
helm -n kube-system upgrade --install metrics-server metrics-server/metrics-server \
  -f {env}-values.yaml --version 3.12.1 --dry-run   # always --dry-run first
```

## Karpenter Architecture

### Repository layout

Karpenter itself (controller) and its NodePools are managed with **helm + kustomize**:
the controller manifests are plain kustomize resources (versioned under `base/{version}/`),
and NodePool/EC2NodeClass generation is a **local Helm chart rendered via the kustomize
`helmCharts` generator**.

```
autoscaling/karpenter/
├── base/
│   ├── kustomization.yaml                 # controller: deployment, pdb, rbac, service, sa
│   ├── nodegroups.yaml                    # chart-wide defaults + PROFILE LIBRARY
│   ├── charts/nodegroups/
│   │   ├── Chart.yaml
│   │   └── templates/resources.yaml       # renders 1 EC2NodeClass + 1 NodePool per service
│   ├── {version}/                         # versioned controller manifests (0.36.2 ... 1.6.0)
│   └── crds/{version}/                    # CRDs per Karpenter version
└── overlays/
    ├── prod/  staging/  dev/  qa/  alpha/  office/  platform/  openclaw/
    ├── {sub-platform}-prod/  {sub-platform}-staging/
    └── {env}/
        ├── kustomization.yaml             # helmCharts + controller patches
        └── patches/patch-nodegroups.yaml  # env values layered via additionalValuesFiles
```

```yaml
# overlays/{env}/kustomization.yaml
resources:
  - ../../base                             # controller

helmGlobals:
  chartHome: ../../base/charts/

helmCharts:
  - name: nodegroups
    releaseName: nodegroups
    includeCRDs: false
    valuesFile: ../../base/nodegroups.yaml # defaults + profile library
    additionalValuesFiles:
      - patches/patch-nodegroups.yaml      # env overlay

patches:
  - target: { kind: Deployment, name: karpenter }
    path: patches/patch-deployment.yaml
  - target: { kind: ServiceAccount }
    path: patches/patch-service-account.yaml
```

### Values model: defaults + profile library + nodePools

`base/nodegroups.yaml` provides chart-wide defaults and a **profile library**; each env's
`patch-nodegroups.yaml` layers on top. Rendering produces **one EC2NodeClass + one
NodePool per service** listed in each pool's `services`.

```yaml
# base/nodegroups.yaml (shape)
defaults:
  # ── NodeClass ──
  osProfile: al2023                        # chart default OS
  nodeClassSpec:
    tags: { Team: devops }                 # propagate mandatory tags to nodes
  # ── NodePool ──
  weight: 10
  startupTaintProfiles: [cilium-not-ready] # chart-wide Cilium readiness gate
  # ── Disruption ──
  expireAfter: Never
  disruption:
    consolidateAfter: 5m
    consolidationPolicy: WhenEmptyOrUnderutilized
  profiles:
    os: { al2023: ..., bottlerocket: ... }
    taints: { service: ..., cicd: ..., cron: ..., monitoring: ..., system-critical: ..., gpu: ... }
    startupTaints: { cilium-not-ready: ... }
    requirements: { category-c: ..., cpu-2-8: ..., zone-abc: ..., capacity-spot-on-demand: ..., ... }
    budgets: { service-hours: ..., peak-hours: ..., non-prod-consolidation: ..., rate-10-percent: ... }
```

#### Merge semantics

| Area | Merge behavior |
|------|----------------|
| `defaults.nodeClassSpec` / `defaults.disruption` / `defaults.profiles` | **deep-merge** (overlay overrides per key) |
| `defaults.requirementProfiles` / `nodePools` (list) | **replace** (overlay decides wholesale) |
| Per-pool `requirements` (list, by key) | per-pool **overrides env-wide by key** |
| Per-pool `disruption` (map) | **deep-merge** over env default |
| Per-pool `startupTaints` (list) | inherits env default unless `startupTaintProfiles` set; inline `[]` opts out |

#### Profile library (5 categories)

Reusable building blocks referenced **by name** from overlays:

**os** — AMI alias + matching blockDeviceMappings as one unit
| Name | Content |
|------|---------|
| `al2023` | Amazon Linux 2023, single `/dev/xvda` gp3 |
| `bottlerocket` | Bottlerocket, `/dev/xvda` + `/dev/xvdb` (containerd data) |

**taints** — NodePool taints (`system-type=<name>:NoSchedule` pattern)
| Name | Taint |
|------|-------|
| `service`, `cicd`, `cron`, `monitoring`, `chaos-mesh` | `system-type=<name>:NoSchedule` |
| `system-critical` | `system-critical=yes:NoSchedule` |
| `gpu` | `nvidia.com/gpu:NoSchedule` |

**startupTaints** — applied at boot, removed when the daemon is ready
| Name | Taint |
|------|-------|
| `cilium-not-ready` | `node.cilium.io/agent-not-ready=true:NoExecute` |

Applied chart-wide via `defaults.startupTaintProfiles: [cilium-not-ready]`.
Opt-out per pool (`startupTaintProfiles: []` — e.g. system-critical pools that must boot
before Cilium) or env-wide for clusters without Cilium.

**requirements** — grouped by Karpenter requirement categories
| Karpenter category | Profiles | Key |
|--------------------|----------|-----|
| Instance Types | `category-c/m/r/cm` | `karpenter.k8s.aws/instance-category` |
| | `family-g6`, `family-g4dn` | `karpenter.k8s.aws/instance-family` |
| | `gen-baseline` (Gt 2), `gen-recommended` (Gt 6) | `karpenter.k8s.aws/instance-generation` |
| | `cpu-4`, `cpu-8`, `cpu-16`, `cpu-2-4`, `cpu-2-8`, `cpu-4-8`, `cpu-4-16`, `cpu-8-16` | `karpenter.k8s.aws/instance-cpu` |
| | `size-large/xlarge/2xlarge` | `karpenter.k8s.aws/instance-size` |
| | `hypervisor-nitro`, `no-flex` | hypervisor / capability-flex |
| Availability Zones | `zone-ac`, `zone-abc` | `topology.kubernetes.io/zone` |
| Architecture | `arch-amd64`, `arch-arm64`, `arch-multi` | `kubernetes.io/arch` |
| Capacity Type | `capacity-on-demand`, `capacity-spot-on-demand` | `karpenter.sh/capacity-type` |

**budgets** — disruption budget patterns (referenced via `budgetProfiles`)
| Name | Effect |
|------|--------|
| `service-hours` | Block disruption KST Mon–Fri 09:00–18:00 (business hours) |
| `peak-hours` | Block disruption KST Mon–Fri 07:00–23:00 (peak traffic) |
| `non-prod-consolidation` | Empty/Drifted always 20%; Underutilized 20% cap, effectively allowed only KST 07–09 & 13–14 windows (requires `WhenEmptyOrUnderutilized`) |
| `rate-10-percent` | Max 10% of pool disrupted at once |

> **Design rule: no inline `requirements:`/`taints:` in overlays.** New patterns are
> registered in `base/nodegroups.yaml` `profiles.*` first, then referenced by name.
> This keeps (a) the full requirement/taint catalog in one place, (b) value changes
> single-sourced (e.g. bump `gen-recommended` cutoff once), and (c) typo-proof keys.

#### Canonical field order

Field groups follow the Karpenter resource model: **NodeClass → NodePool → Disruption**.

```yaml
# overlays/{env}/patches/patch-nodegroups.yaml
_anchors:                        # YAML merge anchors (env-local)
  pool: &pool-env
    terminationGracePeriod: 3m
    limits: { cpu: 500 }

defaults:
  # ── NodeClass ──
  osProfile:                     # env-wide OS override (chart default = al2023)
  nodeClassSpec:
    role: {company}-{env}
    securityGroupSelectorTerms: [{ tags: { karpenter.sh/discovery: {company}-{env} } }]
    subnetSelectorTerms:        [{ tags: { karpenter.sh/discovery: {company}-{env} } }]
    metadataOptions: { httpTokens: optional }
    tags: { karpenter.sh/discovery: {company}-{env}, Env: {env} }
  # ── NodePool ──
  startupTaintProfiles:          # env-wide startup taints ([] to opt out env-wide)
  requirementProfiles: [gen-baseline, hypervisor-nitro, zone-abc, arch-multi, capacity-spot-on-demand]
  # ── Disruption ──
  disruption:                    # rare — chart defaults usually suffice

nodePools:
  - <<: *pool-env
    name: cron
    services: [cron]
    volumeSize: 30Gi
    kubelet: { maxPods: 20 }
    taintProfiles: [cron]
    requirementProfiles: [category-c, cpu-2-4]

  - <<: *pool-env
    name: frontend               # block disruption during peak hours
    services: [frontend]
    volumeSize: 20Gi
    taintProfiles: [service]
    requirementProfiles: [category-c, cpu-2-8]
    budgetProfiles: [peak-hours]

  - <<: *pool-env
    name: system-critical        # must boot before Cilium — opt out of startup taint
    services: [system-critical]
    volumeSize: 20Gi
    labels: { system-critical: "yes" }
    taintProfiles: [system-critical]
    startupTaintProfiles: []
    requirementProfiles: [category-m, cpu-2-4]
```

#### osProfile resolution

`osProfile` resolves **per-pool > env > `al2023` (chart default)** — useful for gradual
OS migrations (e.g. one env on Bottlerocket) or single-pool exceptions.

#### Adding a new pattern (workflow)

1. Add the entry to `base/nodegroups.yaml` `profiles.requirements` (e.g. `family-g7`)
2. Reference it from the pool: `requirementProfiles: [..., family-g7]`
3. Reuse the same name in any other env/pool

One file (`base/nodegroups.yaml`) is the guaranteed catalog of every possible
requirement; overlay files are just "recipes" combining named ingredients.

### Render & apply

```bash
# Render (review the output diff before applying)
kustomize build ./overlays/{env} --enable-helm --load-restrictor=LoadRestrictionsNone > {env}.yaml

# Apply
kustomize build ./overlays/{env} --enable-helm --load-restrictor=LoadRestrictionsNone | kubectl apply -f -
```

Rendered outputs are committed per env (`{company}-{env}.yaml`) so `git diff` shows the
exact manifest change a values edit produces.

### NodeGroup service categories

| Group | Instance category | Taint | Use case |
|-------|-------------------|-------|----------|
| standard services | m (general) | `system-type: service` | API microservices |
| cpu-optimized | c (compute) | `system-type: service` | Gateways, heavy compute |
| monitoring | r (memory) | `system-type: monitoring` | Prometheus, Loki, Grafana |
| cron | c (compute) | `system-type: cron` | Scheduled jobs, batch |
| cicd | c/m | `system-type: cicd` | CI/CD runners |
| gpu | g4dn/g6 | `nvidia.com/gpu` | ML inference |
| system-critical | m (general) | `system-critical=yes` (no startup taint) | CoreDNS, Karpenter, critical |

### IAM / bootstrap prerequisites

- `KarpenterControllerRole-{cluster}` and `KarpenterNodeRole-{cluster}` per cluster
  (CloudFormation templates versioned under `scripts/`, secrets via git-secret)
- Node role added to `aws-auth` (`system:bootstrappers`, `system:nodes`)
- Spot interruption handling: SQS queue via the Karpenter CloudFormation reference stack

### Karpenter version history

| Version | API | Key changes |
|---------|-----|-------------|
| 0.36.2 | v1beta1 | Initial adoption |
| 0.37.7 | v1beta1 | Webhook support added |
| 1.0.7 | v1 | GA release, API stabilization |
| 1.6.0 | v1 | Current — improved consolidation; profile-library values model |
| 1.8.x | v1 | Prepared (CloudFormation/manifests staged under `scripts/`) |

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
3. **Karpenter**: Update controller manifests (`base/{version}/`) and CRDs (`base/crds/{version}/`)
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
| General workloads, cost-optimized | Karpenter with `capacity-spot-on-demand` + consolidation |
| System/infra pods (karpenter, monitoring) | Managed Node Groups (on-demand) or `system-critical` pool |
| GPU/ML workloads | Karpenter `family-g4dn`/`family-g6`, on-demand only |
| Stateful workloads (databases) | Managed Node Groups with EBS |
| CI/CD runners | Karpenter `cicd` pool with `kubelet.maxPods` |
| Production APIs | Karpenter `capacity-on-demand`, AZ-constrained, `peak-hours` budget |
| Non-prod cost control | `non-prod-consolidation` budget (business-hours-safe consolidation) |

## Troubleshooting Quick Reference

| Symptom | Check |
|---------|-------|
| Pods pending | `kubectl describe pod` -> Events, NodePool limits, subnet capacity |
| Node not joining | EC2 console -> instance logs, security groups, IAM role, aws-auth |
| Node joins but pods never schedule | Startup taint stuck — is Cilium agent ready? (`cilium-not-ready` startup taint) |
| Karpenter not scaling | Controller logs, NodePool status, EC2 capacity |
| CNI errors | VPC CNI version, prefix delegation config, IP exhaustion |
| Consolidation stuck | Check PDB, pod anti-affinity, `do-not-disrupt` annotations, budget windows |
| Consolidation not happening in non-prod | `non-prod-consolidation` blocks Underutilized outside KST 07–09/13–14 by design |
| First install fails | Install controller first; apply NodePools/EC2NodeClasses only after controller is Running |
