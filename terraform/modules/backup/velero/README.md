# Velero Backup Module

Deploys Velero for Kubernetes cluster backup and disaster recovery with AWS S3 backend.

## Overview

This module provisions Velero on EKS clusters with:
- S3 bucket for backup storage with KMS encryption
- EBS volume snapshots via AWS APIs
- IRSA for secure AWS access without static credentials
- Automated backup schedules
- Optional Prometheus ServiceMonitor integration

## Features

- Automated S3 bucket creation with versioning and lifecycle policies
- KMS encryption for backups at rest with automatic key rotation
- Multi-tier storage: Standard → Standard-IA (30d) → Glacier Instant Retrieval (90d)
- Configurable backup schedules (daily/weekly defaults)
- IRSA-based authentication (no long-lived credentials)
- EBS snapshot support for persistent volumes
- Prometheus metrics and ServiceMonitor

## Usage

```hcl
module "velero" {
  source = "../../modules/backup/velero"

  cluster_name       = "prod-cluster-01"
  region             = "us-east-1"
  oidc_provider_arn  = module.eks.oidc_provider_arn
  oidc_issuer_url    = module.eks.cluster_oidc_issuer_url

  install                = true
  backup_retention_days  = 30
  enable_service_monitor = true

  backup_schedules = {
    daily = {
      schedule = "0 2 * * *"  # 2 AM daily
      template = {
        ttl                     = "720h"  # 30 days
        includeClusterResources = true
        snapshotVolumes         = true
      }
    }
    weekly = {
      schedule = "0 3 * * 0"  # 3 AM Sunday
      template = {
        ttl                     = "2160h"  # 90 days
        includeClusterResources = true
        snapshotVolumes         = true
      }
    }
  }

  tags = {
    cluster     = "prod-cluster-01"
    environment = "prod"
    backup      = "velero"
  }

  providers = {
    kubernetes = kubernetes.hub
    helm       = helm.hub
  }
}
```

## Using Existing S3 Bucket

```hcl
module "velero" {
  source = "../../modules/backup/velero"

  cluster_name       = "prod-cluster-01"
  region             = "us-east-1"
  oidc_provider_arn  = module.eks.oidc_provider_arn
  oidc_issuer_url    = module.eks.cluster_oidc_issuer_url

  create_bucket = false
  bucket_name   = "existing-velero-bucket"
  bucket_arn    = "arn:aws:s3:::existing-velero-bucket"
  kms_key_arn   = "arn:aws:kms:us-east-1:123456789012:key/abc123..."

  tags = {
    cluster     = "prod-cluster-01"
    environment = "prod"
  }
}
```

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|----------|
| cluster_name | Name of the EKS cluster | string | - | yes |
| region | AWS region | string | - | yes |
| oidc_provider_arn | ARN of the OIDC provider for IRSA | string | - | yes |
| oidc_issuer_url | URL of the OIDC issuer | string | - | yes |
| install | Whether to install Velero via Helm | bool | true | no |
| namespace | Kubernetes namespace for Velero | string | "velero" | no |
| velero_version | Velero Helm chart version | string | "7.1.4" | no |
| velero_plugin_version | Velero AWS plugin version | string | "v1.10.0" | no |
| create_bucket | Whether to create S3 bucket for backups | bool | true | no |
| bucket_name | Name of existing S3 bucket (if create_bucket = false) | string | "" | no |
| bucket_arn | ARN of existing S3 bucket (if create_bucket = false) | string | "" | no |
| kms_key_arn | ARN of existing KMS key (if create_bucket = false) | string | "" | no |
| backup_retention_days | Number of days to retain backups | number | 30 | no |
| backup_schedules | Backup schedules in cron format | map(object) | See below | no |
| enable_service_monitor | Enable Prometheus ServiceMonitor for Velero | bool | true | no |
| tags | Tags to apply to resources | map(string) | {} | no |

### Default Backup Schedules

```hcl
{
  daily = {
    schedule = "0 2 * * *"  # 2 AM daily
    template = {
      ttl                     = "720h"  # 30 days
      includeClusterResources = true
      snapshotVolumes         = true
    }
  }
}
```

## Outputs

| Name | Description |
|------|-------------|
| bucket_id | S3 bucket ID for Velero backups |
| bucket_arn | S3 bucket ARN for Velero backups |
| kms_key_id | KMS key ID for backup encryption |
| iam_role_arn | IAM role ARN for Velero IRSA |
| namespace | Kubernetes namespace for Velero |

## Dependencies

### Terraform Providers
- hashicorp/aws >= 5.0
- hashicorp/kubernetes >= 2.0
- hashicorp/helm >= 2.0

### External Dependencies
- EKS cluster with OIDC provider configured
- Cilium CNI (or other CNI) must be operational
- Prometheus Operator CRDs (if enable_service_monitor = true)

### Module Dependencies
```
cluster_factory → cilium → velero
```

## Resources Created

### AWS Resources
- S3 bucket (if create_bucket = true)
  - Versioning enabled
  - KMS encryption
  - Lifecycle policies (Standard → IA → Glacier)
  - Public access blocked
- KMS key (if create_bucket = true)
  - Automatic key rotation enabled
  - Key alias
- IAM role for IRSA
- IAM policy (S3, EC2, KMS permissions)

### Kubernetes Resources
- Namespace (velero)
- Velero Helm release
- ServiceAccount with IRSA annotation
- ServiceMonitor (if enabled)

## IAM Permissions

Velero IRSA role has permissions for:
- S3: GetObject, PutObject, DeleteObject, ListBucket
- EC2: CreateSnapshot, DeleteSnapshot, DescribeVolumes, DescribeSnapshots
- KMS: Encrypt, Decrypt, GenerateDataKey, DescribeKey

## Storage Lifecycle

Backups transition through storage tiers:
1. **Standard** (0-30 days): Hot storage for recent backups
2. **Standard-IA** (30-90 days): Infrequent access for older backups
3. **Glacier Instant Retrieval** (90+ days): Long-term archival
4. **Expiration**: After backup_retention_days (default: 30)

## Backup Operations

### Create On-Demand Backup

```bash
velero backup create manual-backup-$(date +%Y%m%d-%H%M%S) \
  --include-namespaces=production \
  --snapshot-volumes=true
```

### List Backups

```bash
velero backup get
```

### Restore from Backup

```bash
velero restore create --from-backup daily-20260104020000
```

### Delete Backup

```bash
velero backup delete daily-20260101020000
```

## Monitoring

When `enable_service_monitor = true`, Velero exports metrics to Prometheus:
- `velero_backup_success_total` - Successful backups count
- `velero_backup_failure_total` - Failed backups count
- `velero_backup_duration_seconds` - Backup duration
- `velero_restore_success_total` - Successful restores count

## Security Considerations

- Uses IRSA (no long-lived credentials in cluster)
- S3 bucket has public access blocked
- KMS encryption for backups at rest with key rotation
- Velero namespace requires `pod-security.kubernetes.io/enforce: privileged`
- IAM policy follows least privilege (scoped to specific bucket)

## Troubleshooting

### Check Velero Status

```bash
kubectl logs -n velero deployment/velero
velero backup-location get
```

### Backup Failures

```bash
velero backup describe <backup-name> --details
velero backup logs <backup-name>
```

### Restore Issues

```bash
velero restore describe <restore-name>
velero restore logs <restore-name>
```

### IRSA Issues

Verify ServiceAccount annotation:
```bash
kubectl get sa velero -n velero -o yaml | grep role-arn
```

## Related Documentation

- [Disaster Recovery Runbook](../../../docs/disaster-recovery-runbook.md)
- [Operations Runbook](../../../docs/operations-runbook.md)
- [Velero Documentation](https://velero.io/docs/)
