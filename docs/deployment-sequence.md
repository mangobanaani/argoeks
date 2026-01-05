# Deployment Sequence Guide

## Overview

This guide outlines the correct order of operations for deploying the ArgoEKS platform to avoid dependency issues.

## Why Deployment Order Matters

Some components depend on CRDs (Custom Resource Definitions) or resources created by other components:
- **Cilium ServiceMonitors** require Prometheus Operator CRDs
- **Karpenter** requires Cilium CNI to be functional
- **ArgoCD Applications** require cluster to be fully operational

## Initial Cluster Deployment

### Stage 1: Core Infrastructure

Deploy the base cluster without optional monitoring integrations:

```bash
cd terraform/environments/dev

# Initial apply - creates VPC, EKS, Cilium (without ServiceMonitor)
terraform apply
```

**What gets created:**
- VPC with subnets and NAT gateways
- EKS cluster control plane
- Node groups with proper taints
- Cilium CNI (full replacement mode)
- Karpenter controller
- Security groups and IAM roles

**Verify cluster is ready:**
```bash
# Update kubeconfig
aws eks update-kubeconfig --name dev-mlops-cluster-01 --region us-east-1

# Check nodes are Ready
kubectl get nodes

# Verify Cilium is running
kubectl get pods -n kube-system -l k8s-app=cilium

# Check Cilium status
kubectl exec -n kube-system ds/cilium -- cilium status
```

### Stage 2: Observability Stack

Deploy Prometheus Operator and monitoring stack via ArgoCD or Helm:

**Option A: Via ArgoCD** (Recommended)
```bash
# ArgoCD should auto-sync the kube-prometheus-stack application
kubectl get applications -n argocd

# Wait for Prometheus Operator CRDs
kubectl wait --for condition=established --timeout=60s \
  crd/servicemonitors.monitoring.coreos.com \
  crd/prometheusrules.monitoring.coreos.com \
  crd/podmonitors.monitoring.coreos.com
```

**Option B: Manual Helm Install**
```bash
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

helm install kube-prometheus-stack prometheus-community/kube-prometheus-stack \
  -n monitoring --create-namespace \
  -f kubernetes/platform/observability/kube-prometheus-stack/values.yaml
```

**Verify CRDs are installed:**
```bash
kubectl get crd | grep monitoring.coreos.com
```

Expected output:
```
servicemonitors.monitoring.coreos.com
prometheusrules.monitoring.coreos.com
podmonitors.monitoring.coreos.com
...
```

### Stage 3: Enable Cilium Monitoring

Now that Prometheus Operator CRDs exist, enable Cilium ServiceMonitors:

```bash
cd terraform/environments/dev

# Edit clusters.tf and change:
# enable_prometheus_servicemonitor = false
# to:
# enable_prometheus_servicemonitor = true

# Apply the change
terraform apply -target=module.cilium_hub
```

**Verify ServiceMonitors created:**
```bash
kubectl get servicemonitor -n kube-system
```

Expected output:
```
NAME              AGE
cilium-agent      1m
cilium-operator   1m
hubble            1m
```

**Verify metrics are being scraped:**
```bash
# Port-forward to Prometheus
kubectl port-forward -n monitoring svc/prometheus-operated 9090:9090

# Open http://localhost:9090 and query:
# cilium_endpoint_state
```

### Stage 4: Additional Platform Components

Deploy remaining platform components in this order:

1. **Velero** (if enabled)
   ```bash
   terraform apply -target=module.velero
   ```

2. **KEDA** (if enabled)
   ```bash
   terraform apply -target=module.keda
   ```

3. **Managed Grafana** (if enabled)
   ```bash
   terraform apply -target=module.managed_grafana
   ```

4. **Apply Prometheus Rules**
   ```bash
   kubectl apply -f kubernetes/platform/observability/prometheus-rules/
   ```

5. **Deploy SLO Dashboard**
   ```bash
   # If using Managed Grafana, upload via AWS Console or Terraform
   # If using in-cluster Grafana, import the JSON dashboard
   ```

## Production Deployment

For production environments, follow the same sequence but with additional validation steps:

### Pre-Deployment Checklist

- [ ] Terraform plan reviewed and approved
- [ ] Backup of current state taken
- [ ] Maintenance window scheduled
- [ ] Stakeholders notified
- [ ] Rollback plan documented

### Production-Specific Settings

Update production configuration before deployment:

```hcl
# terraform/environments/prod/clusters.tf

# Ensure production settings
module "cilium_hub" {
  # ... other settings ...

  # Start with monitoring disabled for initial deployment
  enable_prometheus_servicemonitor = false

  # Enable encryption for production
  enable_encryption = true

  # HA settings
  hubble_relay_enabled = true
}
```

### Post-Deployment Validation

After each stage, run validation:

```bash
# Stage 1 validation
./automation/scripts/admin/cluster-health-check.sh prod-mlops-cluster-01

# Stage 2 validation
kubectl get pods -n monitoring
kubectl get prometheusrules -A

# Stage 3 validation
kubectl get servicemonitor -n kube-system
kubectl exec -n kube-system ds/cilium -- cilium status

# Run Cilium connectivity test
kubectl exec -n kube-system -ti ds/cilium -- cilium connectivity test
```

## Multi-Environment Deployment

When deploying across dev → qa → prod:

### Week 1: Dev Environment
1. Deploy Stage 1 (core infrastructure)
2. Deploy Stage 2 (observability)
3. Enable Stage 3 (Cilium monitoring)
4. Run full validation
5. Monitor for 3-5 days

### Week 2: QA Environment
1. Repeat dev deployment sequence
2. Run integration tests
3. Load testing with monitoring
4. Monitor for 3-5 days

### Week 3-4: Prod Environment
1. Schedule maintenance window
2. Deploy during low-traffic period
3. Use blue-green or canary if available
4. Extended monitoring period (7 days)

## Troubleshooting

### ServiceMonitor CRD Not Found

**Error:**
```
Error: resource mapping not found for name: "cilium-agent" namespace: "kube-system"
from "": no matches for kind "ServiceMonitor" in version "monitoring.coreos.com/v1"
ensure CRDs are installed first
```

**Solution:**
1. Verify Prometheus Operator is installed:
   ```bash
   kubectl get crd servicemonitors.monitoring.coreos.com
   ```

2. If CRD doesn't exist, install Prometheus Operator:
   ```bash
   helm install kube-prometheus-stack prometheus-community/kube-prometheus-stack -n monitoring
   ```

3. Wait for CRD to be ready:
   ```bash
   kubectl wait --for condition=established --timeout=60s \
     crd/servicemonitors.monitoring.coreos.com
   ```

4. Retry Cilium deployment:
   ```bash
   terraform apply -target=module.cilium_hub
   ```

### Cilium Pods Not Starting

**Check node taints:**
```bash
kubectl get nodes -o json | jq '.items[].spec.taints'
```

If nodes have `node.cilium.io/agent-not-ready:NoExecute` taint, this is expected. Cilium will remove it when ready.

**Check Cilium logs:**
```bash
kubectl logs -n kube-system -l k8s-app=cilium --tail=100
```

### Karpenter Not Provisioning Nodes

**Verify Cilium is ready first:**
```bash
kubectl exec -n kube-system ds/cilium -- cilium status | grep "KubeProxyReplacement"
```

Should show: `KubeProxyReplacement: True`

**Check Karpenter logs:**
```bash
kubectl logs -n karpenter deployment/karpenter
```

## Rollback Procedures

### Rollback Stage 3 (Disable ServiceMonitors)

```bash
cd terraform/environments/dev

# Edit clusters.tf:
# enable_prometheus_servicemonitor = false

terraform apply -target=module.cilium_hub
```

### Rollback Stage 2 (Remove Observability)

```bash
# Via ArgoCD
kubectl delete application kube-prometheus-stack -n argocd

# Or via Helm
helm uninstall kube-prometheus-stack -n monitoring
```

### Full Cluster Rollback

```bash
cd terraform/environments/dev

# Destroy in reverse order
terraform destroy -target=module.keda
terraform destroy -target=module.velero
terraform destroy -target=module.cilium_hub
terraform destroy -target=module.cluster_factory
```

## Quick Reference

### Minimal Deployment Commands

```bash
# Stage 1: Core
cd terraform/environments/dev
terraform apply
aws eks update-kubeconfig --name dev-mlops-cluster-01 --region us-east-1
kubectl get nodes

# Stage 2: Observability
kubectl wait --for condition=established --timeout=60s crd/servicemonitors.monitoring.coreos.com

# Stage 3: Enable monitoring
# Edit clusters.tf: enable_prometheus_servicemonitor = true
terraform apply -target=module.cilium_hub
kubectl get servicemonitor -n kube-system
```

### Health Check Commands

```bash
# Cluster health
./automation/scripts/admin/cluster-health-check.sh dev-mlops-cluster-01

# Backup verification
./automation/scripts/admin/backup-verification.sh dev-mlops-cluster-01 dev

# Cost report
./automation/scripts/admin/cost-report.sh
```

## Related Documentation

- [Cloud Architecture Review](cloud-architecture-review.md) - Platform assessment
- [Disaster Recovery Runbook](disaster-recovery-runbook.md) - DR procedures
- [Operations Runbook](operations-runbook.md) - Day-2 operations
- [Implementation Summary](implementation-summary.md) - Component details

## Support

For deployment issues:
1. Check logs: `kubectl logs -n <namespace> <pod>`
2. Review this deployment sequence
3. Check component dependencies
4. Consult troubleshooting sections
5. Contact platform team
