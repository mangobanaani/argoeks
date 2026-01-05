# ArgoEKS Administration Scripts

Organized collection of scripts for managing and operating the ArgoEKS platform.

## Directory Structure

```
automation/scripts/
├── admin/          Administrative and operational scripts
├── setup/          One-time setup and bootstrap scripts
├── utils/          Utility and helper scripts
└── dev/            Development and testing scripts
```

## Admin Scripts

### cluster-health-check.sh
Comprehensive cluster health verification.

**Usage**:
```bash
./admin/cluster-health-check.sh dev-mlops-cluster-01
```

**Checks**:
- Cluster status and nodes
- Cilium CNI health
- ArgoCD status and applications
- Karpenter autoscaling
- Velero backup status
- Resource usage
- Failed pods

### backup-verification.sh
Verify all backup systems are working correctly.

**Usage**:
```bash
./admin/backup-verification.sh dev-mlops-cluster-01 dev
```

**Verifies**:
- Velero cluster backups
- RDS automated snapshots
- Terraform state versioning
- S3 cross-region replication (prod only)

### cost-report.sh
Generate AWS cost reports by environment, service, and tags.

**Usage**:
```bash
# Last month's costs
./admin/cost-report.sh

# Custom date range
./admin/cost-report.sh 2026-01-01 2026-01-31 DAILY
```

**Reports**:
- Cost by environment
- Cost by AWS service
- Cost by project tag
- EKS-specific costs

### apply-karpenter-nodes.sh
Apply Karpenter NodePool configurations.

**Usage**:
```bash
./admin/apply-karpenter-nodes.sh dev-mlops-cluster-01
```

## Setup Scripts

### bootstrap-argocd.sh
Initial ArgoCD installation and configuration.

**Usage**:
```bash
./setup/bootstrap-argocd.sh dev-mlops-cluster-01
```

**Actions**:
- Installs ArgoCD via Helm
- Configures admin credentials
- Sets up initial ApplicationSets

### argocd-label-cluster.sh
Add ArgoCD cluster labels for ApplicationSet targeting.

**Usage**:
```bash
./setup/argocd-label-cluster.sh dev-mlops-cluster-01 dev mlops
```

### generate-flux-kustomizations.sh
Generate Flux Kustomization resources from configuration.

**Usage**:
```bash
./setup/generate-flux-kustomizations.sh
```

## Utility Scripts

### discover-alb.sh
Discover AWS Application Load Balancer details.

**Usage**:
```bash
./utils/discover-alb.sh
```

### package-lambda.sh
Package Lambda functions for deployment.

**Usage**:
```bash
./utils/package-lambda.sh <function-name>
```

### render-alerts-from-config.sh
Generate Prometheus AlertManager rules from platform configuration.

**Usage**:
```bash
./utils/render-alerts-from-config.sh
```

### render-grafana-dashboards.sh
Generate Grafana dashboards from templates.

**Usage**:
```bash
./utils/render-grafana-dashboards.sh
```

### vendor-feast.sh
Vendor Feast feature store Helm charts.

**Usage**:
```bash
./utils/vendor-feast.sh
```

### vendor-kubeflow.sh
Vendor Kubeflow manifests.

**Usage**:
```bash
./utils/vendor-kubeflow.sh
```

## Development Scripts

### sandbox-env.sh
Create sandbox environment for testing.

**Usage**:
```bash
./dev/sandbox-env.sh
```

### standardize-modules.sh
Standardize Terraform module structure.

**Usage**:
```bash
./dev/standardize-modules.sh
```

## Common Workflows

### Daily Operations

**Morning Health Check**:
```bash
# Check cluster health
./admin/cluster-health-check.sh prod-mlops-cluster-01

# Verify backups
./admin/backup-verification.sh prod-mlops-cluster-01 prod
```

**Weekly Cost Review**:
```bash
# Generate weekly cost report
./admin/cost-report.sh $(date -v-7d +%Y-%m-%d) $(date +%Y-%m-%d) DAILY
```

**Monthly Tasks**:
```bash
# Full month cost analysis
./admin/cost-report.sh $(date -v-1m +%Y-%m-01) $(date +%Y-%m-%d) MONTHLY
```

### Incident Response

**Cluster Issues**:
```bash
# Quick health check
./admin/cluster-health-check.sh <cluster-name>

# Check recent backups
./admin/backup-verification.sh <cluster-name> <env>
```

**Scaling Issues**:
```bash
# Reapply Karpenter NodePools
./admin/apply-karpenter-nodes.sh <cluster-name>
```

### New Environment Setup

```bash
# 1. Bootstrap ArgoCD
./setup/bootstrap-argocd.sh <cluster-name>

# 2. Label cluster
./setup/argocd-label-cluster.sh <cluster-name> <env> <type>

# 3. Generate Flux kustomizations
./setup/generate-flux-kustomizations.sh

# 4. Verify health
./admin/cluster-health-check.sh <cluster-name>
```

## Script Development Guidelines

### Style Guide
- Use bash strict mode: `set -euo pipefail`
- Include usage instructions
- Add descriptive comments
- Use meaningful variable names
- Validate required inputs

### Error Handling
```bash
if [ -z "$REQUIRED_VAR" ]; then
  echo "Usage: $0 <required-var>"
  exit 1
fi
```

### Logging
```bash
echo "[1/5] Step description..."
echo " Success message"
echo " Error message"
echo " Warning message"
```

## Maintenance

### Adding New Scripts

1. Place script in appropriate directory
2. Make executable: `chmod +x script.sh`
3. Add usage documentation to this README
4. Include inline help in the script
5. Test in dev environment first

### Deprecating Scripts

1. Move to `deprecated/` subdirectory
2. Update this README
3. Add deprecation notice in script
4. Remove after 30 days if no usage

## Support

For issues or questions:
- Check logs: `kubectl logs -n <namespace> <pod>`
- Review runbooks: `docs/disaster-recovery-runbook.md`
- Contact: platform-team

## References

- [Disaster Recovery Runbook](../../docs/disaster-recovery-runbook.md)
- [Cost Allocation Tags](../../docs/cost-allocation-tags.md)
- [Cloud Architecture Review](../../docs/cloud-architecture-review.md)
