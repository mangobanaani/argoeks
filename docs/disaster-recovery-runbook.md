# Disaster Recovery Runbook

## Overview

This runbook provides step-by-step procedures for recovering from various disaster scenarios in the ArgoEKS platform.

## Table of Contents

1. [Backup Architecture](#backup-architecture)
2. [Recovery Scenarios](#recovery-scenarios)
3. [RTO and RPO Targets](#rto-and-rpo-targets)
4. [Pre-Disaster Preparation](#pre-disaster-preparation)
5. [Recovery Procedures](#recovery-procedures)
6. [Testing and Validation](#testing-and-validation)

## Backup Architecture

### Automated Backups

**Velero Backup Schedules**:
- **Daily backups**: 2 AM, 30-day retention
- **Weekly backups**: 3 AM Sunday, 90-day retention
- Includes cluster resources and persistent volumes

**RDS Automated Backups**:
- **Daily snapshots**: Automatic, 7-day retention
- **Point-in-time recovery**: Up to 35 days
- **Multi-region replication**: Enabled for prod

**S3 Versioning and Lifecycle**:
- **Versioning**: Enabled on all state and backup buckets
- **Lifecycle policies**: Transition to Intelligent-Tiering after 90 days

### Backup Locations

```
Primary Region (us-east-1):
- Velero S3 bucket: s3://argoeks-velero-{environment}-{region}/
- Terraform state: s3://argoeks-terraform-state/{environment}/
- RDS snapshots: AWS RDS automatic backups

Secondary Region (eu-west-1) [prod only]:
- RDS read replica with automated snapshots
- Cross-region S3 replication for critical data
```

## Recovery Scenarios

### Scenario 1: Single Pod/Deployment Failure
**RTO**: 5 minutes | **RPO**: 0 (no data loss)

### Scenario 2: Node Failure
**RTO**: 10 minutes | **RPO**: 0

### Scenario 3: Availability Zone Failure
**RTO**: 15 minutes | **RPO**: 5 minutes

### Scenario 4: Complete Cluster Failure
**RTO**: 2 hours | **RPO**: 1 hour

### Scenario 5: Regional Disaster
**RTO**: 4 hours | **RPO**: 1 hour (prod only)

### Scenario 6: Database Corruption/Loss
**RTO**: 1 hour | **RPO**: 1 hour (point-in-time)

### Scenario 7: Terraform State Loss
**RTO**: 30 minutes | **RPO**: 0 (versioned)

## RTO and RPO Targets

| Environment | RTO Target | RPO Target | Multi-Region |
|-------------|-----------|------------|--------------|
| dev         | 4 hours   | 24 hours   | No           |
| qa          | 2 hours   | 4 hours    | No           |
| prod        | 1 hour    | 1 hour     | Yes          |

## Pre-Disaster Preparation

### Daily Checks

```bash
# Verify Velero backup status
kubectl get backup -n velero
kubectl get schedule -n velero

# Check latest backup
kubectl describe backup -n velero $(kubectl get backup -n velero --sort-by=.metadata.creationTimestamp -o name | tail -1)

# Verify RDS snapshots
aws rds describe-db-snapshots --db-instance-identifier prod-mlops-db --max-records 5

# Verify Terraform state backup
aws s3 ls s3://argoeks-terraform-state/ --recursive | tail -10
```

### Weekly Validation

1. Test Velero restore to dev cluster
2. Verify cross-region replication (prod)
3. Review backup logs for failures
4. Validate monitoring alerts

### Monthly DR Test

1. Full cluster recovery simulation in sandbox environment
2. Database restore test
3. Update runbook with lessons learned

## Recovery Procedures

### 1. Single Pod/Deployment Failure

**Detection**: Pod CrashLoopBackOff, deployment not ready

```bash
# Check pod status
kubectl get pods -A | grep -v Running

# Check events
kubectl get events --sort-by='.lastTimestamp' -A | tail -20

# Restart deployment
kubectl rollout restart deployment <deployment-name> -n <namespace>

# Force delete stuck pod
kubectl delete pod <pod-name> -n <namespace> --force --grace-period=0
```

### 2. Node Failure

**Detection**: Node NotReady, pods evicted

```bash
# Check node status
kubectl get nodes

# Cordon failing node
kubectl cordon <node-name>

# Drain workloads
kubectl drain <node-name> --ignore-daemonsets --delete-emptydir-data

# Karpenter will automatically provision replacement node
# Or manually trigger node replacement
kubectl delete node <node-name>
```

### 3. Availability Zone Failure

**Detection**: Multiple nodes NotReady in same AZ

```bash
# Verify AZ distribution
kubectl get nodes -o custom-columns=NAME:.metadata.name,ZONE:.metadata.labels.topology\\.kubernetes\\.io/zone

# Workloads should automatically failover to healthy AZs
# Monitor pod redistribution
watch kubectl get pods -A -o wide

# If manual intervention needed, cordon all nodes in failed AZ
kubectl get nodes -l topology.kubernetes.io/zone=us-east-1a -o name | xargs kubectl cordon
```

### 4. Complete Cluster Failure

**RTO**: 2 hours | **Steps**: 45-60 minutes

#### Step 1: Assess Situation (5 minutes)

```bash
# Attempt cluster access
kubectl get nodes
aws eks describe-cluster --name <cluster-name> --region us-east-1

# Check control plane health
aws eks describe-cluster --name <cluster-name> --query 'cluster.health'
```

#### Step 2: Decision Point

**Option A: Cluster recoverable**   Proceed to component recovery
**Option B: Full rebuild required**   Proceed to Step 3

#### Step 3: Recreate Cluster Infrastructure (30 minutes)

```bash
cd /Users/pekka/Documents/argoeks/terraform/environments/<env>

# Destroy failed cluster (if accessible)
terraform destroy -target=module.cluster_factory -auto-approve

# Recreate cluster
terraform apply -target=module.cluster_factory -auto-approve

# Install Cilium CNI
terraform apply -target=module.cilium_hub -auto-approve

# Verify cluster access
aws eks update-kubeconfig --name <cluster-name> --region us-east-1
kubectl get nodes
```

#### Step 4: Restore Cluster State with Velero (20 minutes)

```bash
# Install Velero
terraform apply -target=module.velero -auto-approve

# Wait for Velero to be ready
kubectl wait --for=condition=available --timeout=300s deployment/velero -n velero

# List available backups
velero backup get

# Identify latest successful backup
LATEST_BACKUP=$(velero backup get --output json | jq -r '.items | sort_by(.status.completionTimestamp) | reverse | .[0].metadata.name')

# Restore from backup
velero restore create --from-backup $LATEST_BACKUP --wait

# Monitor restore progress
velero restore describe <restore-name>
watch kubectl get pods -A
```

#### Step 5: Restore Application Components (10 minutes)

```bash
# ArgoCD will auto-sync applications
kubectl get applications -n argocd

# Force sync if needed
argocd app sync --all

# Verify critical applications
kubectl get pods -n kube-system
kubectl get pods -n monitoring
kubectl get pods -n argocd
```

#### Step 6: Validate and Monitor (10 minutes)

```bash
# Run connectivity tests
kubectl exec -n kube-system -ti ds/cilium -- cilium connectivity test

# Check application health
kubectl get deployment -A
kubectl get ingress -A

# Verify metrics collection
kubectl port-forward -n monitoring svc/prometheus-server 9090:80
# Access http://localhost:9090 and verify metrics

# Check logs for errors
kubectl logs -n kube-system -l k8s-app=cilium --tail=50
```

### 5. Regional Disaster (Prod Only)

**RTO**: 4 hours | **Multi-region failover**

#### Step 1: Activate Secondary Region (30 minutes)

```bash
cd /Users/pekka/Documents/argoeks/terraform/environments/prod

# Promote secondary RDS to primary
aws rds promote-read-replica --db-instance-identifier prod-mlops-db-eu-west-1 --region eu-west-1

# Update Route53 to point to secondary region
aws route53 change-resource-record-sets --hosted-zone-id Z1234567890ABC \
  --change-batch file://failover-to-secondary.json
```

#### Step 2: Deploy to Secondary Cluster

```bash
# Secondary cluster should already exist in eu-west-1
aws eks update-kubeconfig --name prod-mlops-cluster-02 --region eu-west-1

# Restore from Velero backup (replicated to secondary region)
velero restore create --from-backup <latest-backup> --wait
```

#### Step 3: Update Application Configuration

```bash
# Update database endpoints in applications
kubectl set env deployment/<app-name> DB_HOST=prod-mlops-db-eu-west-1.xxx.eu-west-1.rds.amazonaws.com

# Verify application connectivity
kubectl logs -f deployment/<app-name>
```

### 6. Database Corruption/Loss

**RTO**: 1 hour | **Point-in-time recovery**

```bash
# List available snapshots
aws rds describe-db-snapshots --db-instance-identifier <db-instance-id>

# Option A: Restore from automated snapshot
aws rds restore-db-instance-from-db-snapshot \
  --db-instance-identifier <new-instance-id> \
  --db-snapshot-identifier <snapshot-id>

# Option B: Point-in-time restore (within 35 days)
aws rds restore-db-instance-to-point-in-time \
  --source-db-instance-identifier <source-instance> \
  --target-db-instance-identifier <new-instance-id> \
  --restore-time 2025-12-01T10:00:00Z

# Update application database endpoints
kubectl set env deployment/<app-name> DB_HOST=<new-db-endpoint>
```

### 7. Terraform State Loss

**RTO**: 30 minutes | **Recovery from S3 versioning**

```bash
# List S3 versions
aws s3api list-object-versions --bucket argoeks-terraform-state --prefix <env>/terraform.tfstate

# Restore previous version
aws s3api get-object --bucket argoeks-terraform-state \
  --key <env>/terraform.tfstate \
  --version-id <version-id> \
  terraform.tfstate.recovered

# Verify state integrity
terraform state list -state=terraform.tfstate.recovered

# Replace current state
mv terraform.tfstate.recovered <env-dir>/.terraform/terraform.tfstate
terraform state pull
```

## Post-Recovery Actions

### Immediate (Within 1 hour)

1. Notify stakeholders of recovery completion
2. Document incident timeline and root cause
3. Verify all critical services are operational
4. Review monitoring dashboards for anomalies

### Short-term (Within 24 hours)

1. Conduct post-mortem meeting
2. Update runbook with lessons learned
3. Verify backup integrity
4. Create new baseline backups

### Long-term (Within 1 week)

1. Implement preventive measures
2. Update disaster recovery tests
3. Review and adjust RTO/RPO targets
4. Train team on new procedures

## Testing and Validation

### Monthly DR Drill Schedule

**Week 1**: Velero restore test in sandbox
```bash
# Create test namespace
kubectl create namespace dr-test

# Deploy sample application
kubectl create deployment nginx --image=nginx -n dr-test

# Create backup
velero backup create dr-drill-$(date +%Y%m%d) --include-namespaces dr-test

# Delete namespace
kubectl delete namespace dr-test

# Restore
velero restore create --from-backup dr-drill-$(date +%Y%m%d)

# Verify
kubectl get pods -n dr-test
```

**Week 2**: Database snapshot restore
**Week 3**: Multi-region failover (prod only)
**Week 4**: Full cluster rebuild simulation

## Contacts and Escalation

### On-Call Rotation
- Primary: Platform team on-call (PagerDuty)
- Secondary: DevOps manager
- Escalation: CTO

### External Vendors
- AWS Support: Enterprise support, 15-minute response SLA
- Datadog: Premium support for monitoring issues

## Monitoring and Alerts

### Critical Alerts
- Cluster unreachable
- Multiple nodes NotReady
- Velero backup failures
- RDS snapshot failures
- Cross-region replication lag > 1 hour

### Dashboard URLs
- Grafana: `https://grafana-{env}.example.com`
- Prometheus: `http://prometheus-server.monitoring.svc:9090`
- ArgoCD: `https://argocd-{env}.example.com`

## Appendix

### Backup Verification Commands

```bash
# Velero backup validation
velero backup describe <backup-name> --details

# Check backup logs
velero backup logs <backup-name>

# RDS snapshot status
aws rds describe-db-snapshots --db-instance-identifier <instance-id> --snapshot-type automated

# S3 bucket versioning
aws s3api get-bucket-versioning --bucket argoeks-terraform-state
```

### Recovery Time Tracking

Document actual recovery times for continuous improvement:

| Date | Scenario | Planned RTO | Actual Time | Notes |
|------|----------|-------------|-------------|-------|
| ... | ... | ... | ... | ... |

## Version History

| Version | Author | Changes |
|---------|--------|---------|
| 1.0 | Platform Team | Initial creation |
