# Cilium + Karpenter Implementation Summary

## What's Been Implemented

### 1. Terraform Infrastructure Changes

#### Cluster Factory Module (`terraform/modules/cluster_factory/`)

**Subnet Tags** (Already present, confirmed):
- Private subnets: `karpenter.sh/discovery = cluster-name`
- Public subnets: `karpenter.sh/discovery = cluster-name`

**Security Group Tags** (Added):
```hcl
node_security_group_tags = {
  "karpenter.sh/discovery" = each.value.name
}
```

**SQS Queue & EventBridge Rules** (Added):
- SQS queue: `{cluster-name}-karpenter`
- EventBridge rules for:
  - EC2 Spot Instance Interruption Warning
  - EC2 Instance Rebalance Recommendation
  - EC2 Instance State-change Notification
  - AWS Health Events
- All events route to Karpenter SQS queue

**Outputs** (Added):
- `karpenter_interruption_queue_names` - Map of cluster names to SQS queue names
- `karpenter_interruption_queue_urls` - Map of cluster names to SQS queue URLs

#### Karpenter Module (`terraform/modules/karpenter/`)

**Updated to v1.1.1**:
- Chart version: `1.1.1` (was `0.16.3`)
- Repository: `oci://public.ecr.aws/karpenter` (was `https://charts.karpenter.sh`)
- API version: `karpenter.k8s.aws/v1` and `karpenter.sh/v1` (was `v1beta1`)

**Enhanced Configuration**:
- Added `replicas = 2` for HA
- Added `interruptionQueue` setting
- Added resource requests and limits
- Updated metadata options for ENI mode compatibility

#### Dev Environment (`terraform/environments/dev/`)

**Enabled Karpenter Module**:
- Uncommented Karpenter module block
- Updated to use cluster_factory outputs
- Added dependency on `module.cilium_hub`
- Set chart version to `1.1.1`

### 2. Platform Manifests

#### Karpenter NodeClasses (`platform/karpenter/nodeclasses/`)

**default.yaml**:
- AMI: Amazon Linux 2023
- Instance metadata configured for Cilium ENI mode
- User data script tags instances with `cni=cilium`
- Subnet/SG discovery via `karpenter.sh/discovery` tags

**gpu.yaml**:
- AMI: Amazon Linux 2023 with GPU support
- NVIDIA driver installation in user data
- Larger root volume (500GB for models/datasets)
- Higher IOPS/throughput for ML workloads
- Tags: `workload-type=gpu`, `nvidia.com/gpu=present`

#### Karpenter NodePools (`platform/karpenter/nodepools/`)

**general.yaml**:
- Instance families: m, c, r (generation 6+)
- Capacity: spot + on-demand (spot-preferred)
- Consolidation: 5m after empty/underutilized
- Startup taint: `node.cilium.io/agent-not-ready`
- Limits: 2000 CPU, 4000Gi memory

**gpu.yaml**:
- Instance types: g5, p4d, p5 series
- Capacity: on-demand + spot (on-demand-preferred)
- Taints: `nvidia.com/gpu=true`, `workload-type=gpu`
- Consolidation: 30m after empty only (conservative)
- Limits: 500 CPU, 2000Gi memory, 100 GPUs

### 3. GitOps Configuration

#### ArgoCD ApplicationSets (`gitops/argocd/`)

**applicationset-cilium.yaml**:
- Deploys Cilium 1.16.5 from Helm chart
- Uses values from `platform/cilium/values.yaml`
- Injects k8s API endpoint from cluster annotations
- Server-side apply enabled
- Auto-heal enabled, prune disabled

**applicationset-karpenter.yaml**:
- Deploys Karpenter 1.1.1 from OCI registry
- Injects Karpenter IRSA role ARN from annotations
- Applies NodeClass/NodePool from `platform/karpenter/`
- Auto-heal and prune enabled
- Creates `karpenter` namespace

### 4. Helper Scripts

**scripts/apply-karpenter-nodes.sh**:
- Auto-detects cluster name from kubectl context
- Replaces `CLUSTER_NAME` placeholders in manifests
- Applies NodeClass and NodePool configurations
- Verifies Karpenter and Cilium installation
- Supports dry-run mode

### 5. Documentation

**docs/cilium-karpenter-deployment.md**:
- Full deployment guide with all phases
- Troubleshooting section
- Configuration options
- Testing procedures

**docs/deployment-quickstart.md**:
- Minimal command reference
- Quick verification checklist

## Deployment Sequence

### Step 1: Apply Terraform Infrastructure

```bash
cd terraform/environments/dev

# Initialize (if first time)
terraform init

# Plan and review
terraform plan -out=tfplan

# Apply infrastructure
terraform apply tfplan
```

**What gets created**:
- EKS cluster with tagged subnets and security groups
- SQS queue for Karpenter interruptions
- EventBridge rules for spot/health events
- Karpenter IAM roles (controller + nodes)
- Karpenter instance profile
- Cilium installed via Terraform module
- Karpenter installed via Terraform module

### Step 2: Apply Karpenter Node Configurations

**Option A: Using helper script**:
```bash
./scripts/apply-karpenter-nodes.sh
```

**Option B: Manual application**:
```bash
CLUSTER_NAME=$(kubectl config view --minify -o jsonpath='{.clusters[0].name}')
sed "s/CLUSTER_NAME/$CLUSTER_NAME/g" platform/karpenter/nodeclasses/default.yaml | kubectl apply -f -
sed "s/CLUSTER_NAME/$CLUSTER_NAME/g" platform/karpenter/nodeclasses/gpu.yaml | kubectl apply -f -
kubectl apply -f platform/karpenter/nodepools/
```

### Phase 3: Verify Installation

```bash
# Check Cilium
kubectl -n kube-system get pods -l app.kubernetes.io/name=cilium
kubectl -n kube-system exec ds/cilium -- cilium status

# Check Karpenter
kubectl -n karpenter get pods
kubectl get ec2nodeclasses,nodepools

# Test node provisioning
kubectl create deployment test --image=public.ecr.aws/eks-distro/kubernetes/pause:3.7
kubectl scale deployment test --replicas=5
kubectl get nodes -w
```

## Key Configuration Points

### Cilium ENI Mode

Already configured in `platform/cilium/values.yaml`:
```yaml
eni:
  enabled: true
  awsReleaseExcessIPs: true
ipam:
  mode: eni
routingMode: native
kubeProxyReplacement: strict
```

**Benefits**:
- Pod IPs are VPC-native (work with security groups, flow logs)
- No encapsulation overhead
- Compatible with Karpenter auto-scaling
- eBPF datapath for performance

**Important**: AWS VPC CNI addon remains enabled for bootstrap, but Cilium handles pod networking.

### Karpenter Discovery

Karpenter finds resources using tags:
```hcl
"karpenter.sh/discovery" = "cluster-name"
```

Applied to:
-  Private subnets
-  Public subnets
-  Node security group

### Interruption Handling

SQS queue receives events from:
- Spot instance interruption (2-minute warning)
- Instance rebalance recommendations
- Instance state changes
- AWS Health events

Karpenter drains and replaces nodes gracefully.

## Validation Checklist

- [ ] Terraform apply completed without errors
- [ ] Cilium pods running in `kube-system` namespace
- [ ] Cilium status shows `IPAM: AWS ENI`
- [ ] Karpenter pods running in `karpenter` namespace
- [ ] NodeClasses created (`kubectl get ec2nodeclasses`)
- [ ] NodePools created (`kubectl get nodepools`)
- [ ] SQS queue exists (`aws sqs list-queues | grep karpenter`)
- [ ] EventBridge rules exist (`aws events list-rules | grep karpenter`)
- [ ] Test deployment scaled successfully
- [ ] New nodes have correct tags and labels

## Troubleshooting

### Issue: Karpenter not provisioning nodes

**Check**:
```bash
# Karpenter logs
kubectl logs -n karpenter -l app.kubernetes.io/name=karpenter --tail=100

# Pending pods
kubectl get pods -A --field-selector=status.phase=Pending

# NodePool status
kubectl describe nodepool general
```

**Common causes**:
- Missing subnet tags
- Missing security group tags
- IAM permissions for node role
- Instance type not available in AZ

### Issue: Pods stuck in ContainerCreating

**Check**:
```bash
# Cilium status
kubectl -n kube-system exec ds/cilium -- cilium status

# CNI logs
kubectl -n kube-system logs -l app.kubernetes.io/name=cilium --tail=100

# Pod events
kubectl describe pod <pod-name>
```

**Common causes**:
- Cilium not ready on new node
- ENI attachment failures
- VPC IP exhaustion

### Issue: CiliumNode stuck

Known issue during rapid scaling:
```bash
# List stuck nodes
kubectl get ciliumnodes

# Delete to trigger recreation
kubectl delete ciliumnode <node-name>
```

## Cost Optimization

### Spot Instances

General pool configured for spot:
```yaml
requirements:
  - key: karpenter.sh/capacity-type
    operator: In
    values: ["spot", "on-demand"]  # Spot preferred
```

**Savings**: ~70% compared to on-demand

### Consolidation

Karpenter automatically consolidates underutilized nodes:
```yaml
disruption:
  consolidationPolicy: WhenEmptyOrUnderutilized
  consolidateAfter: 5m
```

**Savings**: Eliminates idle nodes within 5 minutes

### GPU Nodes

GPU pool uses conservative consolidation:
```yaml
disruption:
  consolidationPolicy: WhenEmpty  # Only consolidate when completely empty
  consolidateAfter: 30m            # Wait 30 minutes
```

**Rationale**: GPU training jobs are expensive to interrupt

## Next Steps

1. **Enable Monitoring**:
   - Add Prometheus ServiceMonitors for Cilium
   - Add Prometheus ServiceMonitors for Karpenter
   - Create Grafana dashboards

2. **Network Policies**:
   ```bash
   kubectl apply -f policies/network-policies.yaml
   ```

3. **Enable Prefix Delegation** (optional, for higher pod density):
   ```yaml
   # In platform/cilium/values.yaml
   eni:
     awsEnablePrefixDelegation: true
   ```

4. **GitOps via ArgoCD** (future):
   - Register cluster in ArgoCD
   - Apply ApplicationSets
   - Let ArgoCD manage Cilium and Karpenter upgrades

5. **Production Hardening**:
   - Enable encryption (WireGuard)
   - Configure PodDisruptionBudgets
   - Set up cluster mesh (multi-cluster)
   - Enable AWS GuardDuty integration

## Files Modified/Created

### Modified
- `terraform/modules/cluster_factory/main.tf` - Added SQS queue, EventBridge rules, node SG tags
- `terraform/modules/cluster_factory/outputs.tf` - Added Karpenter queue outputs
- `terraform/modules/karpenter/variables.tf` - Updated chart version to 1.1.1
- `terraform/modules/karpenter/main.tf` - Updated to v1 APIs and OCI registry
- `terraform/environments/dev/clusters.tf` - Enabled Karpenter module

### Created
- `gitops/argocd/applicationset-cilium.yaml`
- `gitops/argocd/applicationset-karpenter.yaml`
- `platform/karpenter/nodeclasses/default.yaml`
- `platform/karpenter/nodeclasses/gpu.yaml`
- `platform/karpenter/nodepools/general.yaml`
- `platform/karpenter/nodepools/gpu.yaml`
- `scripts/apply-karpenter-nodes.sh`
- `docs/cilium-karpenter-deployment.md`
- `docs/deployment-quickstart.md`
- `docs/IMPLEMENTATION-SUMMARY.md` (this file)

## References

- [Cilium ENI Documentation](https://docs.cilium.io/en/latest/network/concepts/ipam/eni/)
- [Karpenter v1 Migration](https://karpenter.sh/docs/upgrading/v1-migration/)
- [EKS Best Practices - Networking](https://aws.github.io/aws-eks-best-practices/security/docs/network/)
- [Karpenter Interruption Handling](https://karpenter.sh/docs/concepts/disruption/)
