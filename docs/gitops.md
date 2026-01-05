# GitOps & Argo CD

Concepts
- Argo CD manages platform/apps via Applications and fleet‑wide ApplicationSets.
- Clusters are registered in Argo CD; labeling a cluster (Secret) controls inclusion.

Key manifests
- Bootstrap Argo to self‑manage: `gitops/argocd/app-argocd-platform.yaml` (projects, repos, settings).
- Fleet ApplicationSets: RBAC, Observability, ExternalDNS, Grafana dashboards, Kubeflow.

Cluster selection
- ApplicationSets use the cluster generator. Label a cluster Secret:
  - `scripts/argocd-label-cluster.sh <secret> kubeflow=enabled`

Workflows
- Platform updates (values, policies) land in Git   Argo CD syncs.
- Per‑env overlays live under `platform/...` (e.g., observability, kubeflow).

Tips
- Keep admin access minimal; rely on SSO groups and AppProject roles.
- Use `Prune` + `SelfHeal` for drift correction; pair with Gatekeeper for guardrails.
