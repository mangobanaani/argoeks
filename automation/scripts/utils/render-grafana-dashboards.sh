#!/usr/bin/env bash
set -euo pipefail

CFG=${1:-configuration/platform.yaml}

if ! command -v yq >/dev/null 2>&1; then
  echo "yq is required (https://mikefarah.gitbook.io/yq/)" >&2
  exit 1
fi

base="platform/observability/grafana-dashboards"
mkdir -p "$base"

envs=$(yq e '.envs | keys | .[]' "$CFG")
for env in $envs; do
  dir="$base/$env"
  mkdir -p "$dir"
  ids=$(yq e ".envs.$env.monitoring.grafana.dashboard_ids[]" "$CFG" 2>/dev/null || true)
  if [[ -z "${ids}" ]]; then
    echo "No dashboard_ids configured for $env; skipping"
    continue
  fi
  # ConfigMap with dashboard id:rev list (newline-separated)
  printf "apiVersion: v1\nkind: ConfigMap\nmetadata:\n  name: grafana-dashboard-ids\n  namespace: monitoring\ndata:\n  dashboards: |\n" > "$dir/dashboards-configmap.yaml"
  while IFS= read -r line; do
    [[ -z "$line" ]] && continue
    printf "    %s\n" "$line" >> "$dir/dashboards-configmap.yaml"
  done <<< "$ids"

  cat > "$dir/job.yaml" <<'YAML'
apiVersion: batch/v1
kind: Job
metadata:
  name: grafana-dashboards-fetch
  namespace: monitoring
spec:
  template:
    spec:
      serviceAccountName: grafana-dashboards-loader
      restartPolicy: OnFailure
      containers:
      - name: fetch
        image: bitnami/kubectl:1.29
        command:
        - /bin/bash
        - -lc
        - |
          set -euo pipefail
          install_packages curl jq
          mkdir -p /dashboards
          while IFS= read -r pair; do
            [[ -z "$pair" ]] && continue
            id=${pair%%:*}
            rev=${pair##*:}
            if [[ "${rev}" == "${id}" || "${rev}" == "latest" ]]; then
              rev=$(curl -s https://grafana.com/api/dashboards/${id}/revisions | jq -r 'max_by(.revision).revision')
            fi
            echo "Fetching dashboard ${id} rev ${rev}"
            curl -fsSL -o /dashboards/${id}-${rev}.json \
              https://grafana.com/api/dashboards/${id}/revisions/${rev}/download
          done < <(echo "$DASHBOARDS")
          # Create or update ConfigMaps for Grafana sidecar
          for f in /dashboards/*.json; do
            name="grafana-dashboard-$(basename "$f" .json)"
            kubectl -n monitoring create configmap "$name" \
              --from-file="$f" \
              --dry-run=client -o yaml | \
              kubectl label -f - --overwrite grafana_dashboard="1" | \
              kubectl apply -f -
          done
        env:
        - name: DASHBOARDS
          valueFrom:
            configMapKeyRef:
              name: grafana-dashboard-ids
              key: dashboards
YAML

  # Kustomization that includes common RBAC and env files
  cat > "$dir/kustomization.yaml" <<KUST
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
  - ../common/rbac.yaml
  - dashboards-configmap.yaml
  - job.yaml
KUST
  echo "Rendered $dir"
done

