#!/usr/bin/env bash
set -euo pipefail

CFG=${1:-configuration/platform.yaml}
ENV=${2:-dev}

if ! command -v yq >/dev/null 2>&1; then
  echo "yq is required (https://mikefarah.gitbook.io/yq/)" >&2
  exit 1
fi

over="platform/kubeflow/overlays/${ENV}"
mkdir -p "$over/generated"

host=$(yq e ".envs.${ENV}.kubeflow.host" "$CFG")
issuer=$(yq e ".envs.${ENV}.kubeflow.oidc.issuer" "$CFG")
client_id=$(yq e ".envs.${ENV}.kubeflow.oidc.client_id" "$CFG")
cert_arn=$(yq e ".envs.${ENV}.kubeflow.acm_cert_arn" "$CFG")
bucket=$(yq e ".envs.${ENV}.kubeflow.pipelines.bucket" "$CFG")
region=$(yq e ".envs.${ENV}.region // .envs.${ENV}.aws.region // "us-east-1"" "$CFG")
secret_ref=$(yq e ".envs.${ENV}.kubeflow.oidc.client_secret_ssm" "$CFG")
secret_provider=$(yq e ".envs.${ENV}.kubeflow.oidc.client_secret_provider // "ssm"" "$CFG")

cat > "$over/generated/dex-config.yaml" <<YAML
issuer: http://dex.auth.svc.cluster.local:5556
storage:
  type: kubernetes
  config:
    inCluster: true
web:
  http: 0.0.0.0:5556
connectors:
- type: oidc
  id: sso
  name: SSO
  config:
    issuer: ${issuer}
    clientID: ${client_id}
    clientSecret: REPLACE_AT_RUNTIME
    redirectURI: https://${host}/dex/callback
    userIDKey: sub
    scopes: [openid, email, profile]
YAML

if sed --version >/dev/null 2>&1; then
  # GNU sed
  sed -i -e "s#REPLACE_WITH_ACM_CERT_ARN#${cert_arn}#g" "$over/patches/istio-gateway-svc.yaml" || true
  sed -i -e "s#REPLACE_WITH_S3_BUCKET_NAME#${bucket}#g" -e "s#REPLACE_WITH_REGION#${region}#g" "$over/patches/pipeline-configmap.yaml" || true
else
  # BSD sed (macOS)
  sed -i '' -e "s#REPLACE_WITH_ACM_CERT_ARN#${cert_arn}#g" "$over/patches/istio-gateway-svc.yaml" || true
  sed -i '' -e "s#REPLACE_WITH_S3_BUCKET_NAME#${bucket}#g" -e "s#REPLACE_WITH_REGION#${region}#g" "$over/patches/pipeline-configmap.yaml" || true
fi

echo "Rendered Kubeflow overlay for ${ENV}. Update Dex clientSecret via ExternalSecret or replace inline before apply."

# ExternalSecret for Dex clientSecret using clientSecretFile
mkdir -p "$over/externalsecrets"
store="aws"
if [[ "$secret_provider" == "ssm" ]]; then store="aws-ssm"; fi
cat > "$over/externalsecrets/dex-clientsecret.yaml" <<YAML
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: dex-oidc
  namespace: auth
spec:
  refreshInterval: 1h
  secretStoreRef:
    kind: ClusterSecretStore
    name: ${store}
  target:
    name: dex-oidc
    creationPolicy: Owner
  data:
  - secretKey: clientSecret
    remoteRef:
      key: ${secret_ref}
YAML

# Patch Dex deployment to mount clientSecretFile
mkdir -p "$over/patches"
cat > "$over/patches/dex-deployment.yaml" <<'YAML'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: dex
  namespace: auth
spec:
  template:
    spec:
      volumes:
      - name: dex-oidc
        secret:
          secretName: dex-oidc
      containers:
      - name: dex
        volumeMounts:
        - name: dex-oidc
          mountPath: /etc/dex/oidc
          readOnly: true
YAML
