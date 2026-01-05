# VPC Lattice Core - Multi-VPC Service Mesh

Creates an AWS VPC Lattice service network for cross-VPC and cross-region service communication.

## Overview

VPC Lattice is a fully managed application networking service that simplifies service-to-service communication across VPCs, accounts, and regions. Use this module when you need service mesh capabilities without the complexity of VPC peering or Transit Gateway.

## When to Use

**Recommended for**:
- Multi-region service communication (e.g., primary to secondary prod)
- Cross-environment service access (e.g., dev to qa shared services)
- Multi-account service sharing with fine-grained IAM control
- Hybrid architectures (EKS + Lambda + EC2 services)
- Tenant service isolation with controlled cross-tenant access

**Use with Cilium Cluster Mesh**:
- **Cilium**: Fast pod-to-pod within clusters (eBPF)
- **VPC Lattice**: Service-level routing across VPCs/regions (AWS-managed)
- Both are complementary, not mutually exclusive

**Not recommended for**:
- Single VPC with single cluster (use Cilium only)
- Pod-to-pod communication (use Cilium cluster mesh)
- Cost-sensitive environments with simple networking needs

## Usage

### Basic Service Network

```hcl
module "vpc_lattice" {
  source = "../../modules/ingress/vpc_lattice_core"

  name    = "prod-service-network"
  vpc_ids = values(module.cluster_factory.vpc_ids)

  tags = {
    environment = "prod"
    purpose     = "multi-region-mesh"
  }
}
```

### Multi-Region Setup (Prod Example)

```hcl
# Primary region
module "vpc_lattice_primary" {
  source = "../../modules/ingress/vpc_lattice_core"
  providers = { aws = aws.primary }

  name    = "prod-primary-network"
  vpc_ids = module.cluster_factory_primary.vpc_ids

  tags = { region = "us-east-1" }
}

# Secondary region
module "vpc_lattice_secondary" {
  source = "../../modules/ingress/vpc_lattice_core"
  providers = { aws = aws.secondary }

  name    = "prod-secondary-network"
  vpc_ids = module.cluster_factory_secondary.vpc_ids

  tags = { region = "us-west-2" }
}
```

### Exposing Services via VPC Lattice

```hcl
# Example: vLLM inference service accessible cross-region
resource "aws_vpclattice_service" "vllm_inference" {
  name                       = "vllm-inference"
  custom_domain_name         = "vllm.internal.example.com"
  auth_type                  = "AWS_IAM"
  service_network_identifier = module.vpc_lattice.service_network_id

  tags = { workload = "ml-inference" }
}

# Target group pointing to K8s service
resource "aws_vpclattice_target_group" "vllm" {
  name = "vllm-targets"
  type = "IP"

  config {
    port             = 8080
    protocol         = "HTTP"
    vpc_identifier   = module.cluster_factory.vpc_ids[0]
    ip_address_type  = "IPV4"
  }
}
```

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|----------|
| name | Service network name | string | - | yes |
| vpc_ids | List of VPC IDs to associate | list(string) | - | yes |
| tags | Resource tags | map(string) | {} | no |

## Outputs

| Name | Description |
|------|-------------|
| service_network_id | VPC Lattice service network ID |
| service_network_arn | VPC Lattice service network ARN |

## Cost Estimate

- **Service network**: Free
- **Service**: ~$0.025/hour per service (~$18/month)
- **Data transfer**: $0.01/GB within region, $0.02/GB cross-region
- **Typical multi-region setup**: ~$50-100/month for 3-5 services

## Integration with Cilium

VPC Lattice and Cilium work together:

| Layer | Technology | Use Case |
|-------|-----------|----------|
| **Pod networking** | Cilium eBPF | Fast intra-cluster communication |
| **Service mesh (cluster)** | Cilium cluster mesh | Cross-cluster pod communication |
| **Service mesh (VPC/region)** | VPC Lattice | Cross-VPC/region/account services |

**Example architecture**:
```
Pod A (Cluster 1, VPC 1)
  ↓ Cilium eBPF
Pod B (Cluster 1, VPC 1)

Pod A (Cluster 1, VPC 1)
  ↓ Cilium Cluster Mesh
Pod C (Cluster 2, VPC 1)

Service A (VPC 1, us-east-1)
  ↓ VPC Lattice
Service B (VPC 2, us-west-2)
```

## Example: MLOps Use Cases

**1. Multi-Region Model Serving**
```
Primary region: Training clusters + MLflow
Secondary region: Inference endpoints
VPC Lattice: Primary MLflow → Secondary inference metadata
```

**2. Cross-Environment Model Promotion**
```
Dev: Model experimentation
QA: Model validation
Prod: Production serving
VPC Lattice: Shared MLflow across all environments
```

**3. Tenant Isolation**
```
Tenant A: Training cluster + models
Tenant B: Training cluster + models
Shared: Feast feature store
VPC Lattice: Both tenants → shared Feast with IAM policies
```

## Notes

- VPC Lattice is optional and not enabled by default
- See `terraform/environments/dev/optional-modules.tf.example` for ready-to-use configuration
- For detailed use cases, see `docs/STACK_OPTIMIZATION_2026-01.md`
- Module status: **Ready-to-use** (uncomment when needed)
