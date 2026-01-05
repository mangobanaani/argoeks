#!/usr/bin/env bash
set -euo pipefail

CFG=${1:-configuration/platform.yaml}

if ! command -v yq >/dev/null 2>&1; then
  echo "yq is required (https://mikefarah.gitbook.io/yq/)" >&2
  exit 1
fi

out_base="platform/external-secrets/alertmanager"
mkdir -p "$out_base"

envs=$(yq e '.envs | keys | .[]' "$CFG")
for env in $envs; do
  secret_name=$(yq e ".envs.$env.monitoring.alertmanager_secret_name" "$CFG")
  dir="$out_base/$env"
  mkdir -p "$dir"
  cat >"$dir/externalsecret.yaml" <<YAML
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: alertmanager-config
  namespace: monitoring
spec:
  refreshInterval: 1m
  secretStoreRef:
    kind: ClusterSecretStore
    name: aws
  target:
    name: alertmanager-main
    creationPolicy: Owner
  data:
  - secretKey: alertmanager.yaml
    remoteRef:
      key: "$secret_name"
YAML
  echo "Rendered $dir/externalsecret.yaml"
done

