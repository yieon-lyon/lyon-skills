# GitOps & ArgoCD Reference

## ArgoCD Architecture

### Deployment Pattern: Kustomize + Overlays

```
argoproj/argocd/basic/
├── base/
│   ├── configmap.yaml              # ArgoCD server configuration
│   ├── argocd-notifications-cm.yaml # Notification channels (Slack)
│   ├── repo-*-secret.yaml          # Git repository credentials
│   └── patches/
│       ├── patch-deployment.yaml   # Resource limits for deployments
│       └── patch-statefulset.yaml  # Resource limits for statefulsets
└── overlays/
    ├── {env-1}/
    │   ├── projects/               # ArgoCD AppProjects
    │   └── secrets/                # Environment-specific secrets
    ├── {env-2}/
    │   ├── projects/
    │   ├── secrets/
    │   └── applications/           # Application manifests
    ├── {env-N}/
    │   └── projects/               # Per-namespace projects
    └── ...
```

### ArgoCD Application Template

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: {service}-{env}
  labels:
    appName: {service}
    kind: api                        # api | task | cron
spec:
  destination:
    namespace: {namespace}
    server: https://kubernetes.default.svc
  source:
    path: api                        # api | task | cron
    repoURL: https://{git-host}/{org}/kubernetes-manifest
    targetRevision: {branch}
    helm:
      valueFiles:
        - {service}-values.yaml
  syncPolicy:
    automated: {}                    # Auto-sync on git push
  project: {env}
```

### Application Types

| Type | Kubernetes Resource | Source Path | Use Case |
|------|---------------------|-------------|----------|
| api | Deployment / Rollout | `api/` | REST API microservices |
| task | Deployment | `task/` | Background workers |
| cron | CronJob | `cron/` | Scheduled batch jobs |
| rollout | Argo Rollout | `api/` | Canary/Blue-Green deploys |

### AppProject per Environment

```yaml
apiVersion: argoproj.io/v1alpha1
kind: AppProject
metadata:
  name: {env}
spec:
  description: "{env} environment"
  sourceRepos:
    - "https://{git-host}/{org}/*"
  destinations:
    - namespace: {env}
      server: https://kubernetes.default.svc
    - namespace: default
      server: https://kubernetes.default.svc
  clusterResourceWhitelist:
    - group: "*"
      kind: "*"
```

### Multi-Environment Namespace Strategy

| Environment | Namespace Pattern | Projects |
|-------------|-------------------|----------|
| Highest env | `default`, `{team}-*` | {env}-project, {team}-project |
| Mid-tier env | `{env}`, `{platform}` | {env}-project, {platform}-project |
| Lower envs | `{env}-1` ~ `{env}-N` | {env}-1-project ~ {env}-N-project |

Supports isolated multi-tenant namespaces for parallel development.

### Notifications (Slack)

ArgoCD notifications ConfigMap integrates with Slack for deployment alerts:
- Sync success/failure notifications
- Health status changes
- Per-environment notification channels

## Batch Application Deployment

### Service Discovery via Text Files

```
overlays/{env}/applications/
├── {env}-deployments.txt    # List of API deployment services
├── {env}-rollouts.txt       # List of Argo Rollout services
├── {env}-tasks.txt          # List of background task services
└── {env}-cronjobs.txt       # List of cron job services
```

### Deployment Script Pattern

```bash
#!/bin/bash
# apply-applications.sh — Create ArgoCD Applications from service lists

ENV="${1:?Usage: $0 <env>}"
NAMESPACE="${ENV}"

# Read services from file
while IFS= read -r service; do
  cat <<EOF | kubectl apply -f -
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: ${service}-${ENV}
spec:
  destination:
    namespace: ${NAMESPACE}
    server: https://kubernetes.default.svc
  source:
    path: api
    repoURL: https://{git-host}/{org}/kubernetes-manifest
    targetRevision: ${ENV}
    helm:
      valueFiles:
        - ${service}-values.yaml
  syncPolicy:
    automated: {}
  project: ${ENV}
EOF
done < "${ENV}-deployments.txt"
```

## GitOps Decision Rules

1. **All manifests in Git**: No `kubectl apply` on upper environments — ArgoCD syncs from Git
2. **Environment branches**: `master` (highest), `{env-1}`, `{env-2}` branches map to clusters
3. **Helm values per service**: Each service has `{service}-values.yaml` in the manifest repo
4. **Auto-sync for lower envs**: Lower environments auto-sync on push; highest env requires manual sync or PR approval
5. **AppProject isolation**: Each environment gets a dedicated AppProject with restricted namespaces and source repos
