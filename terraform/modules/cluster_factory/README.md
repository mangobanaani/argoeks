# Cluster Factory Module

Creates 1-50 EKS clusters with VPCs, managed node groups, and optional Cilium CNI.

## Features

- **Multi-Cluster**: Create 1-50 clusters from a single configuration
- **Automatic Networking**: VPCs with non-overlapping CIDRs, VPC endpoints
- **Security**: KMS encryption, IAM roles, security groups
- **Observability**: CloudWatch logs, optional Cilium + Hubble
- **Autoscaling**: Compatible with Karpenter (default) or Fargate (opt-in)
- **Smart CNI Selection**: Automatic Cilium enablement with Fargate compatibility checks

## Basic Usage

```hcl
module "cluster_factory" {
  source = "../../modules/cluster_factory"

  region         = "us-east-1"
  cluster_count  = 1
  name_prefix    = "mlops"
  environment    = "dev"
  base_cidr      = "10.0.0.0/8"

  cluster_config = {
    type         = "mlops"
    size         = "medium"
    tenancy      = "shared"
    compliance   = "none"
    auto_upgrade = false
    version      = "1.30"
  }

  admin_role_arns    = ["arn:aws:iam::123456789012:role/admin"]
  readonly_role_arns = ["arn:aws:iam::123456789012:role/readonly"]
}
```

## Cilium CNI (Recommended for Karpenter)

Enable Cilium for 2-3x better networking performance:

```hcl
module "cluster_factory" {
  # ... basic config ...

  # Enable Cilium CNI (replaces AWS VPC CNI)
  enable_cilium                 = true
  enable_hubble                 = true   # Network observability
  enable_kube_proxy_replacement = true   # 50% latency reduction
  enable_cluster_mesh           = true   # Multi-cluster networking
}
```

**Compatibility**:
- **EC2 + Karpenter**: Fully supported (default, **recommended**)
- **Fargate**: NOT supported (auto-disables Cilium with warning)

See `docs/COMPUTE_OPTIONS_CNI_COMPATIBILITY.md` for details.

## Fargate Support (Optional, disables Cilium)

```hcl
module "cluster_factory" {
  enable_fargate = true  # Auto-disables Cilium

  fargate_profile_defaults = {
    namespaces = ["serverless", "batch"]
  }
}
```

## Inputs

See `variables.tf` for complete list. Key inputs:

| Name | Description | Type | Default |
|------|-------------|------|---------|
| region | AWS region | string | required |
| cluster_count | Number of clusters (1-50) | number | 1 |
| enable_cilium | Install Cilium CNI | bool | false |
| enable_fargate | Enable Fargate (disables Cilium) | bool | false |

## Outputs

| Name | Description |
|------|-------------|
| cluster_names | List of all cluster names |
| cluster_oidc_issuer_urls | Map of cluster names to their OIDC issuer URLs |
| cluster_oidc_providers | Map of cluster names to their OIDC provider hostpaths (without https://) |
| cluster_oidc_provider_arns | Map of cluster names to their OIDC provider ARNs |
| cilium_enabled | Whether Cilium is active |
| cni_plugin | Active CNI ("cilium" or "aws-vpc-cni") |
| deployment_mode | "ec2-karpenter" or "ec2-fargate-hybrid" |

## References

- `docs/CILIUM_ENABLEMENT.md` - Cilium migration guide
- `docs/COMPUTE_OPTIONS_CNI_COMPATIBILITY.md` - Compute/CNI compatibility matrix
