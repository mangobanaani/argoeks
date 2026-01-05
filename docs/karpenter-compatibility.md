# Karpenter Kubernetes Compatibility Issue

**Last Updated:** January 3, 2026

## Current Status

**Karpenter is temporarily DISABLED** due to Kubernetes version incompatibility.

## The Issue

- **EKS Cluster Version:** 1.34
- **Karpenter Version:** 1.1.1
- **Maximum K8s Support (Karpenter 1.1.1):** 1.33
- **Error:** `karpenter version is not compatible with K8s version 1.34`

## Why This Happened

EKS Auto-Upgrade (enabled in terraform.tfvars) automatically upgraded the cluster from 1.33   1.34. Karpenter 1.1.1 was released before K8s 1.34 and doesn't support it yet.

## AWS EKS Downgrade Limitation

**EKS does NOT allow version downgrades.** Attempting to change from 1.34   1.33 results in:

```
InvalidParameterException: Unsupported Kubernetes minor version update from 1.34 to 1.33
```

## Resolution Options

### Option 1: Wait for Karpenter 1.2+ (Recommended)

**Status:** Karpenter team is working on 1.34 support

- Monitor: https://github.com/aws/karpenter-provider-aws/releases
- Expected timeline: Q1 2026
- **Action:** Re-enable Karpenter once compatible version is released

```hcl
# In terraform.tfvars
enable_karpenter = true  # Change when Karpenter >=1.2 is available
```

### Option 2: Destroy and Recreate Cluster

**Destructive:** Loses all data (RDS, Redis, etc.)

```bash
cd terraform/environments/dev

# Backup data first!
# ... export RDS data, Redis data ...

# Destroy everything
source .env && terraform destroy -auto-approve

# Recreate with K8s 1.33
# Edit terraform.tfvars: version = "1.33"
source .env && terraform apply -auto-approve
```

### Option 3: Manual Node Scaling (Temporary)

Use EKS managed node groups for scaling until Karpenter is available:

```bash
# Scale node group
aws eks update-nodegroup-config \
  --cluster-name dev-mlops-cluster-01 \
  --nodegroup-name default \
  --scaling-config minSize=2,maxSize=10,desiredSize=3
```

## Current Workaround

**Terraform Configuration:**

```hcl
# terraform.tfvars:31
enable_karpenter = false  # Disabled: Karpenter 1.1.1 max K8s version is 1.33 (cluster is 1.34)
```

**Impact:**
-  Cluster fully functional (Cilium CNI, AWS LBC, RDS, Redis all working)
-  3 worker nodes (2x t3.medium) available
-  No auto-scaling beyond managed node group limits
-  No advanced scheduling (spot instances, GPU nodes via Karpenter)

## Preventing Auto-Upgrade

To prevent future auto-upgrades:

```hcl
# terraform.tfvars
cluster_config = {
  auto_upgrade = false  # Disable auto-upgrade
  version      = "1.33" # Pin to specific version
}
```

 **Note:** Must destroy/recreate cluster to apply this retroactively.

## References

- [Karpenter Compatibility Matrix](https://karpenter.sh/docs/upgrading/compatibility/)
- [Karpenter AWS Provider Releases](https://github.com/aws/karpenter-provider-aws/releases)
- [EKS Version Documentation](https://docs.aws.amazon.com/eks/latest/userguide/kubernetes-versions-standard.html)

## Next Steps

1. Monitor Karpenter releases for K8s 1.34 support
2. Update `terraform/modules/karpenter/variables.tf` with new version when available
3. Re-enable in `terraform.tfvars`: `enable_karpenter = true`
4. Run `terraform apply`
