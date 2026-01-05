#!/usr/bin/env bash
set -euo pipefail

# Comprehensive cluster health check script for ArgoEKS
# Usage: ./cluster-health-check.sh [cluster-name]

CLUSTER_NAME="${1:-}"
NAMESPACE="${2:-all}"

if [ -z "$CLUSTER_NAME" ]; then
  echo "Usage: $0 <cluster-name> [namespace]"
  echo "Example: $0 dev-mlops-cluster-01"
  exit 1
fi

echo "===================================="
echo "ArgoEKS Cluster Health Check"
echo "Cluster: $CLUSTER_NAME"
echo "===================================="
echo

# Update kubeconfig
echo "[1/10] Updating kubeconfig..."
aws eks update-kubeconfig --name "$CLUSTER_NAME" --region us-east-1 >/dev/null 2>&1
echo "✓ Kubeconfig updated"
echo

# Check cluster status
echo "[2/10] Checking cluster status..."
CLUSTER_STATUS=$(aws eks describe-cluster --name "$CLUSTER_NAME" --query 'cluster.status' --output text)
echo "Cluster Status: $CLUSTER_STATUS"
echo

# Check nodes
echo "[3/10] Checking node status..."
kubectl get nodes --no-headers | awk '{print $1, $2}' | while read name status; do
  if [ "$status" = "Ready" ]; then
    echo "✓ Node $name: Ready"
  else
    echo "✗ Node $name: $status"
  fi
done
echo

# Check Cilium
echo "[4/10] Checking Cilium status..."
CILIUM_READY=$(kubectl get pods -n kube-system -l k8s-app=cilium --field-selector=status.phase=Running --no-headers | wc -l)
CILIUM_TOTAL=$(kubectl get pods -n kube-system -l k8s-app=cilium --no-headers | wc -l)
echo "Cilium pods: $CILIUM_READY/$CILIUM_TOTAL ready"
if [ "$CILIUM_READY" = "$CILIUM_TOTAL" ]; then
  echo "✓ Cilium healthy"
else
  echo "✗ Cilium degraded"
fi
echo

# Check ArgoCD
echo "[5/10] Checking ArgoCD status..."
kubectl get pods -n argocd -l app.kubernetes.io/name=argocd-server --no-headers | while read name ready status restarts age; do
  if [ "$status" = "Running" ]; then
    echo "✓ ArgoCD Server: $status"
  else
    echo "✗ ArgoCD Server: $status"
  fi
done
echo

# Check ArgoCD applications
echo "[6/10] Checking ArgoCD applications..."
kubectl get applications -n argocd --no-headers | awk '{print $1, $3, $4}' | while read name health sync; do
  if [ "$health" = "Healthy" ] && [ "$sync" = "Synced" ]; then
    echo "✓ $name: Healthy & Synced"
  else
    echo "✗ $name: Health=$health Sync=$sync"
  fi
done
echo

# Check Karpenter
echo "[7/10] Checking Karpenter..."
if kubectl get deployment karpenter -n karpenter >/dev/null 2>&1; then
  KARPENTER_READY=$(kubectl get deployment karpenter -n karpenter -o jsonpath='{.status.readyReplicas}')
  KARPENTER_DESIRED=$(kubectl get deployment karpenter -n karpenter -o jsonpath='{.spec.replicas}')
  echo "Karpenter: $KARPENTER_READY/$KARPENTER_DESIRED ready"
else
  echo "Karpenter: Not installed"
fi
echo

# Check Velero backups
echo "[8/10] Checking Velero backups..."
if kubectl get namespace velero >/dev/null 2>&1; then
  LATEST_BACKUP=$(kubectl get backup -n velero --sort-by=.metadata.creationTimestamp -o jsonpath='{.items[-1].metadata.name}' 2>/dev/null || echo "none")
  BACKUP_STATUS=$(kubectl get backup -n velero "$LATEST_BACKUP" -o jsonpath='{.status.phase}' 2>/dev/null || echo "N/A")
  echo "Latest backup: $LATEST_BACKUP ($BACKUP_STATUS)"
else
  echo "Velero: Not installed"
fi
echo

# Check pod resource usage
echo "[9/10] Top resource-consuming pods..."
kubectl top pods -A --sort-by=memory 2>/dev/null | head -6 || echo "Metrics server not available"
echo

# Check failed pods
echo "[10/10] Checking for failed pods..."
FAILED_PODS=$(kubectl get pods -A --field-selector=status.phase!=Running,status.phase!=Succeeded --no-headers 2>/dev/null | wc -l)
if [ "$FAILED_PODS" -eq 0 ]; then
  echo "✓ No failed pods"
else
  echo "✗ $FAILED_PODS failed pods found:"
  kubectl get pods -A --field-selector=status.phase!=Running,status.phase!=Succeeded
fi
echo

echo "===================================="
echo "Health check complete"
echo "===================================="
