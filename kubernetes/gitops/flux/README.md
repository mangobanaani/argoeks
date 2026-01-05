# Flux GitOps for Multi-Cluster

This directory contains a generator script that reads `cluster-registry/clusters.yaml` and emits one `Kustomization` per cluster to deploy the observability stack.

Usage:

```
make generate-flux
```

This will populate `gitops/flux/generated/` with per-cluster manifests referencing `platform/observability/kube-prometheus-stack`.

