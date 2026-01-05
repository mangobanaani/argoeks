#!/usr/bin/env bash
set -euo pipefail

REGISTRY_FILE=${1:-configuration/clusters/clusters.yaml}
OUT_DIR=${2:-gitops/flux/generated}

if ! command -v yq >/dev/null 2>&1; then
  echo "yq is required (https://mikefarah.gitbook.io/yq/)" >&2
  exit 1
fi

mkdir -p "$OUT_DIR"

count=$(yq '.spec.clusters | length' "$REGISTRY_FILE")
for i in $(seq 0 $((count-1))); do
  name=$(yq -r ".spec.clusters[$i].name" "$REGISTRY_FILE")
  server="https://${name}.k8s.local" # placeholder; replace with real API server if desired

  cat >"$OUT_DIR/${name}-observability.yaml" <<YAML
apiVersion: source.toolkit.fluxcd.io/v1
kind: GitRepository
metadata:
  name: ${name}-repo
  namespace: flux-system
spec:
  interval: 1m
  url: https://example.com/gitops-repo.git
  ref:
    branch: main
---
apiVersion: kustomize.toolkit.fluxcd.io/v1
kind: Kustomization
metadata:
  name: ${name}-observability
  namespace: flux-system
spec:
  interval: 5m
  targetNamespace: monitoring
  prune: true
  wait: true
  kubeConfig:
    secretRef:
      name: ${name}-kubeconfig # create a Secret with kubeconfig for cross-cluster mgmt
  sourceRef:
    kind: GitRepository
    name: ${name}-repo
  path: ./platform/observability/kube-prometheus-stack
  postBuild:
    substitute:
      CLUSTER_NAME: ${name}
YAML
done

echo "Generated $(ls -1 "$OUT_DIR" | wc -l | tr -d ' ') manifests in $OUT_DIR"

