#!/usr/bin/env bash
set -euo pipefail

# Backup verification script for ArgoEKS
# Verifies Velero backups, RDS snapshots, and Terraform state backups

CLUSTER_NAME="${1:-}"
ENVIRONMENT="${2:-dev}"

if [ -z "$CLUSTER_NAME" ]; then
  echo "Usage: $0 <cluster-name> [environment]"
  echo "Example: $0 dev-mlops-cluster-01 dev"
  exit 1
fi

echo "===================================="
echo "ArgoEKS Backup Verification"
echo "Cluster: $CLUSTER_NAME"
echo "Environment: $ENVIRONMENT"
echo "===================================="
echo

# Update kubeconfig
aws eks update-kubeconfig --name "$CLUSTER_NAME" --region us-east-1 >/dev/null 2>&1

# Check Velero backups
echo "[1/4] Verifying Velero backups..."
if kubectl get namespace velero >/dev/null 2>&1; then
  echo "Recent backups:"
  kubectl get backup -n velero --sort-by=.metadata.creationTimestamp | tail -5
  echo

  LATEST_BACKUP=$(kubectl get backup -n velero --sort-by=.metadata.creationTimestamp -o jsonpath='{.items[-1].metadata.name}' 2>/dev/null)
  BACKUP_STATUS=$(kubectl get backup -n velero "$LATEST_BACKUP" -o jsonpath='{.status.phase}' 2>/dev/null)
  BACKUP_TIME=$(kubectl get backup -n velero "$LATEST_BACKUP" -o jsonpath='{.metadata.creationTimestamp}' 2>/dev/null)

  echo "Latest backup: $LATEST_BACKUP"
  echo "Status: $BACKUP_STATUS"
  echo "Created: $BACKUP_TIME"

  if [ "$BACKUP_STATUS" = "Completed" ]; then
    echo "✓ Latest Velero backup successful"
  else
    echo "✗ Latest Velero backup failed or incomplete"
  fi
else
  echo "✗ Velero not installed"
fi
echo

# Check RDS snapshots
echo "[2/4] Verifying RDS snapshots..."
RDS_INSTANCES=$(aws rds describe-db-instances --query "DBInstances[?contains(DBInstanceIdentifier, '$ENVIRONMENT')].DBInstanceIdentifier" --output text)

if [ -n "$RDS_INSTANCES" ]; then
  for instance in $RDS_INSTANCES; do
    echo "Instance: $instance"
    LATEST_SNAPSHOT=$(aws rds describe-db-snapshots \
      --db-instance-identifier "$instance" \
      --snapshot-type automated \
      --query "DBSnapshots | sort_by(@, &SnapshotCreateTime) | [-1]" \
      --output json)

    SNAPSHOT_ID=$(echo "$LATEST_SNAPSHOT" | jq -r '.DBSnapshotIdentifier // "none"')
    SNAPSHOT_TIME=$(echo "$LATEST_SNAPSHOT" | jq -r '.SnapshotCreateTime // "N/A"')
    SNAPSHOT_STATUS=$(echo "$LATEST_SNAPSHOT" | jq -r '.Status // "N/A"')

    echo "  Latest snapshot: $SNAPSHOT_ID"
    echo "  Created: $SNAPSHOT_TIME"
    echo "  Status: $SNAPSHOT_STATUS"

    if [ "$SNAPSHOT_STATUS" = "available" ]; then
      echo "  ✓ RDS snapshot available"
    else
      echo "  ✗ RDS snapshot not available"
    fi
    echo
  done
else
  echo "No RDS instances found for environment: $ENVIRONMENT"
fi
echo

# Check Terraform state backups
echo "[3/4] Verifying Terraform state backups..."
STATE_BUCKET="argoeks-terraform-state"
STATE_KEY="${ENVIRONMENT}/terraform.tfstate"

VERSIONS=$(aws s3api list-object-versions --bucket "$STATE_BUCKET" --prefix "$STATE_KEY" --query 'Versions[0:5].[VersionId,LastModified,Size]' --output text 2>/dev/null || echo "")

if [ -n "$VERSIONS" ]; then
  echo "Recent Terraform state versions:"
  echo "$VERSIONS" | while read version_id modified size; do
    echo "  Version: $version_id"
    echo "  Modified: $modified"
    echo "  Size: $size bytes"
    echo
  done
  echo "✓ Terraform state versioning active"
else
  echo "✗ No Terraform state versions found"
fi
echo

# Check S3 bucket replication (for prod)
echo "[4/4] Verifying S3 replication..."
if [ "$ENVIRONMENT" = "prod" ]; then
  REPLICATION_STATUS=$(aws s3api get-bucket-replication --bucket "$STATE_BUCKET" 2>/dev/null || echo "none")

  if [ "$REPLICATION_STATUS" != "none" ]; then
    echo "✓ S3 cross-region replication enabled"
  else
    echo "⚠ S3 cross-region replication not configured"
  fi
else
  echo "Skipping (non-prod environment)"
fi
echo

echo "===================================="
echo "Backup verification complete"
echo "===================================="
