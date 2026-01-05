# Development Environment

This directory contains the Terraform configuration for the **development environment**.

## Structure

```
dev/
├── main.tf           # All resources, providers, data sources, and locals
├── variables.tf      # Input variable definitions
├── outputs.tf        # Output value definitions
├── terraform.tfvars  # Default values for dev environment
└── README.md         # This file
```

## What's Here

### Infrastructure Components

- **EKS Cluster**: Single hub cluster with Karpenter autoscaler
- **Cilium CNI**: High-performance networking with Hubble observability (enabled by default)
- **GitOps**: ArgoCD and Flux for continuous delivery
- **Security**: AWS Security Hub, GuardDuty, CloudTrail, VPC Flow Logs
- **Networking**: Private DNS, VPC, subnets
- **ML Workloads**: Optional IRSA for vLLM, Triton, Feast, Kubeflow, MLflow

### Key Features

- **Minimal by default**: Only essential services enabled
- **Cilium-first**: Cilium CNI baked in for all clusters
- **GitOps-ready**: ArgoCD and Flux pre-configured
- **Security-enabled**: Compliance scanning and audit logging
- **Cost-optimized**: Karpenter for efficient node scaling

## Usage

### Prerequisites

```bash
# Source AWS credentials
source ../../.env

# Or export manually
export AWS_ACCESS_KEY_ID=xxx
export AWS_SECRET_ACCESS_KEY=xxx
export AWS_DEFAULT_REGION=us-east-1
```

### Initialize

```bash
terraform init
```

### Plan

```bash
terraform plan
```

### Apply

```bash
terraform apply
```

### Destroy

```bash
terraform destroy
```

## Configuration

Edit `terraform.tfvars` to customize:

- **Cluster size**: Adjust `cluster_count` and `cluster_config.size`
- **Features**: Enable/disable services with feature flags
- **Regions**: Change `region` for different AWS regions
- **ML workloads**: Enable specific ML frameworks as needed

## Default Configuration

- **Region**: us-east-1
- **Clusters**: 1 hub cluster
- **Size**: Small (dev-optimized node sizes)
- **Cilium**: Enabled with Hubble
- **Karpenter**: Enabled for autoscaling
- **Security**: Full compliance scanning enabled
- **Databases**: Disabled (enable as needed)

## Common Tasks

### Enable a feature

```hcl
# In terraform.tfvars
enable_rds_postgres = true
```

### Add ML workload support

```hcl
# In terraform.tfvars
enable_vllm_sa_irsa = true
vllm_bucket_arn     = "arn:aws:s3:::my-models-bucket"
vllm_namespace      = "vllm"
```

### Scale up cluster

```hcl
# In terraform.tfvars
cluster_count = 3

cluster_config = {
  size = "medium"  # or "large"
  # ...
}
```

## Notes

- This is a development environment - not for production workloads
- Short log retention periods (7 days) to minimize costs
- RDS snapshots disabled by default (`skip_final_snapshot = true`)
- Monitoring alarms disabled to reduce noise
- Use this as a template for QA/Prod environments
