# Terraform Infrastructure

Infrastructure as Code for MLOps on AWS EKS with Cilium CNI.

## Overview

This Terraform codebase provisions a complete MLOps platform on AWS, featuring:

- **Multi-cluster EKS** with Cilium CNI (default, high-performance networking)
- **GitOps-ready** with ArgoCD and Flux
- **Auto-scaling** with Karpenter
- **ML workloads** support (vLLM, Triton, Feast, Kubeflow, MLflow)
- **Observability** with Thanos, Prometheus, Hubble
- **Security** with GuardDuty, Security Hub, WAF, Network Policies
- **Compliance** ready (CIS, PCI-DSS benchmarks)

## Structure

```
terraform/
├── environments/     # Environment-specific configurations
│   ├── dev/         # Development (1 cluster, minimal)
│   ├── qa/          # QA/Staging (1-3 clusters)
│   ├── prod/        # Production (multi-region HA)
│   └── sandbox/     # Experimentation
├── modules/         # Reusable Terraform modules
│   ├── cluster_factory/      # EKS cluster creation
│   ├── networking/           # Cilium, VPC, DNS
│   ├── gitops_bootstrap/     # ArgoCD + Flux
│   ├── iam/                  # IRSA configurations
│   ├── security/             # WAF, Gatekeeper, Security Hub
│   ├── observability/        # Thanos, Prometheus
│   ├── alerts/               # CloudWatch alarms
│   └── ...                   # 30+ modules
├── org/             # Organization-level configs (optional)
├── scripts/         # Helper scripts
└── README.md        # This file
```

## Quick Start

### Prerequisites

```bash
# Required tools
- Terraform >= 1.5.0
- AWS CLI >= 2.0
- kubectl >= 1.28
- helm >= 3.0

# AWS Credentials
export AWS_ACCESS_KEY_ID=xxx
export AWS_SECRET_ACCESS_KEY=xxx
export AWS_DEFAULT_REGION=us-east-1

# Or use AWS Profile
export AWS_PROFILE=my-profile
```

### Deploy Dev Environment

```bash
# Navigate to dev environment
cd terraform/environments/dev

# Review configuration
cat terraform.tfvars

# Initialize Terraform
terraform init

# Plan changes
terraform plan

# Apply (creates ~30-50 resources)
terraform apply

# Get outputs
terraform output
```

### Access Your Cluster

```bash
# Update kubeconfig
aws eks update-kubeconfig --name dev-mlops-hub-1 --region us-east-1

# Verify connection
kubectl get nodes
kubectl get pods -A

# Check Cilium status
kubectl -n kube-system exec -it ds/cilium -- cilium status
```

## Architecture

### Network Architecture

```
┌─────────────────────────────────────────┐
│           AWS Account                    │
│  ┌────────────────────────────────────┐ │
│  │  VPC (10.0.0.0/8)                  │ │
│  │  ├── Public Subnets (NAT GW)       │ │
│  │  ├── Private Subnets (EKS nodes)   │ │
│  │  └── Database Subnets (RDS)        │ │
│  │                                     │ │
│  │  ┌──────────────────────────────┐  │ │
│  │  │  EKS Cluster                 │  │ │
│  │  │  ├── Control Plane           │  │ │
│  │  │  ├── Karpenter Nodes         │  │ │
│  │  │  ├── Cilium CNI              │  │ │
│  │  │  │   ├── Hubble UI           │  │ │
│  │  │  │   └── Network Policies    │  │ │
│  │  │  ├── ArgoCD                  │  │ │
│  │  │  ├── Flux                    │  │ │
│  │  │  └── ML Workloads            │  │ │
│  │  └──────────────────────────────┘  │ │
│  └────────────────────────────────────┘ │
│                                         │
│  Security Layer:                        │
│  ├── Security Hub                       │
│  ├── GuardDuty                          │
│  ├── CloudTrail                         │
│  ├── VPC Flow Logs                      │
│  └── WAF (for public endpoints)         │
└─────────────────────────────────────────┘
```

### Cilium CNI (Default)

Cilium is **always enabled** as the primary CNI:

- **eBPF-based** networking (kernel bypass)
- **Hubble** for network observability
- **Kube-proxy replacement** (better performance)
- **Network policies** (L3/L4/L7)
- **Cluster mesh** (multi-cluster connectivity)
- **Bandwidth management**

### Multi-Account & AWS Organizations

- `org/` contains Terraform that bootstraps AWS Organizations: OUs for **Security**, **Shared Services**, and **Workloads**, dedicated accounts (data, training, serving, experiments, sandbox), guardrail SCPs (TLS-only, deny unsupported regions, block SSM/Instance Connect except approved automation roles, and deny ad-hoc IAM access keys), delegated GuardDuty/Security Hub/Config admins, and an organization-wide CloudTrail bucket with optional replication.
- Declare new accounts via `org/account_map.auto.tfvars` (see `.example`). Each definition outputs the assume-role ARN Terraform should use (`OrganizationAccountAccessTerraform` by default). After editing, run `terraform -chdir=org init && terraform -chdir=org apply` from repo root.
- Every environment is cross-account ready. Populate `workload_account_role_arn`, `workload_account_id`, `management_role_arn`, and (optionally) `assume_role_external_id` in `terraform/environments/<env>/terraform.tfvars` to have Terraform assume into the workload account while billing/alerts read from the management/payer account provider alias.
- See `docs/runbooks/multi-account.md` for operational guidance (adding accounts, rotating roles, verifying SCP coverage).

## Directory Guide

### `/environments/`

Environment-specific configurations. Each environment is self-contained:

```
dev/
├── main.tf           # Complete infrastructure
├── variables.tf      # Input definitions
├── outputs.tf        # Output values
├── terraform.tfvars  # Environment values
└── README.md         # Environment docs
```

**See**: [environments/README.md](./environments/README.md)

### `/modules/`

Reusable Terraform modules organized by category:

- **Core**: `cluster_factory`, `karpenter`
- **Networking**: `cilium`, `private_dns`, `vpc_endpoints_mlops`
- **GitOps**: `gitops_bootstrap`, `flux_tenants`
- **Security**: `security_services`, `gatekeeper`, `waf_acl`
- **IAM**: `irsa`, `irsa_s3`, `irsa_ml_workloads`
- **Databases**: `rds_postgres`, `aurora`, `aurora_global`
- **Observability**: `thanos_aggregator`, `amp`, `amg`
- **Alerts**: `notifications`, `alb_alarms`, `rds_alarms`, `budgets`
- **ML**: `feast`, `kuberay`

**See**: [modules/README.md](./modules/README.md)

### `/org/` (Optional)

Organization-wide resources (e.g., centralized security admin).

### `/scripts/`

Helper scripts for maintenance and automation.

## Configuration

### Environment Variables

```bash
# AWS credentials (choose one)
export AWS_ACCESS_KEY_ID=xxx        # Direct credentials
export AWS_SECRET_ACCESS_KEY=xxx
export AWS_DEFAULT_REGION=us-east-1

# OR
export AWS_PROFILE=my-profile        # Named profile

# Optional
export TF_VAR_cluster_count=3        # Override variables
```

### Using .env File

```bash
# Create .env file (gitignored)
cat > .env << 'EOF'
export AWS_ACCESS_KEY_ID=xxx
export AWS_SECRET_ACCESS_KEY=xxx
export AWS_DEFAULT_REGION=us-east-1
EOF

# Source it
source .env
```

### Terraform Variables

Edit `terraform.tfvars` in each environment:

```hcl
# Cluster configuration
cluster_count = 1
cluster_config = {
  type    = "mlops"
  size    = "small"
  version = "1.30"
}

# Feature flags
enable_argocd    = true
enable_cilium    = true  # Always true (default)
enable_karpenter = true

# ML workloads
enable_vllm_sa_irsa = false
enable_kubeflow     = false
```

## Security

### Credentials Management

- **Never commit** `.env` files (already in `.gitignore`)
- **Never commit** `terraform.tfvars` with secrets
- **Use AWS profiles** when possible
- **Rotate credentials** regularly
- **Use least-privilege IAM** roles

### State Management

**Recommended**: Remote state in S3

```hcl
# In each environment's main.tf
terraform {
  backend "s3" {
    bucket         = "my-terraform-state"
    key            = "argoeks/dev/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "terraform-locks"
    encrypt        = true
  }
}
```

### Network Security

- Private subnets for all workloads
- Network policies enabled (via Gatekeeper)
- VPC Flow Logs to CloudWatch
- WAF on public endpoints
- Security groups following least-privilege

### Compliance

- Security Hub with CIS 1.4 + PCI-DSS benchmarks
- GuardDuty threat detection
- CloudTrail audit logging
- Inspector vulnerability scanning
- Automated compliance reports

## Cost Optimization

### Dev Environment
- **Estimated**: $200-500/month
- **Savings**:
  - Karpenter autoscaling (shut down unused nodes)
  - Spot instances where applicable
  - Short log retention (7 days)
  - Minimal monitoring

### Production Environment
- **Estimated**: $2000-5000/month
- **Features**:
  - Multi-region HA
  - Reserved instances
  - Long-term log storage
  - Full observability stack

### Cost Control

```hcl
# Enable budgets and alerts
module "budgets" {
  source = "../../modules/alerts/budgets"

  limit_amount = 1000  # USD
  thresholds   = [70, 85, 95, 100]
  emails       = ["team@example.com"]
}
```

## Common Tasks

### Add New Cluster

```hcl
# In terraform.tfvars
cluster_count = 3  # Increase from 1
```

### Enable ML Workload

```hcl
# In terraform.tfvars
enable_vllm_sa_irsa = true
vllm_bucket_arn     = "arn:aws:s3:::my-models"
vllm_namespace      = "vllm"
```

### Upgrade Cilium

```hcl
# In terraform.tfvars (or variables.tf for module)
cilium_version = "1.17.0"  # Update version
```

### Enable Database

```hcl
# In terraform.tfvars
enable_rds_postgres = true
rds_instance_class  = "db.t4g.large"
```

### Destroy Environment

```bash
cd terraform/environments/dev
terraform destroy
```

## Troubleshooting

### State Lock

```bash
# List locks
aws dynamodb scan --table-name terraform-locks

# Force unlock (careful!)
terraform force-unlock <lock-id>
```

### Provider Issues

```bash
# Reinitialize
rm -rf .terraform .terraform.lock.hcl
terraform init -upgrade
```

### Plan Errors

```bash
# Validate syntax
terraform validate

# Format code
terraform fmt -recursive

# Check for drift
terraform plan -refresh-only
```

### Module Not Found

```bash
# Reinitialize to download modules
terraform init
```

## Documentation

- **This README**: Overview and quick start
- **[environments/README.md](./environments/README.md)**: Environment details
- **[modules/README.md](./modules/README.md)**: Module catalog
- **Individual module READMEs**: Detailed module documentation

## Contributing

1. Create feature branch
2. Make changes
3. Test in `sandbox` environment
4. Format code: `terraform fmt -recursive`
5. Validate: `terraform validate`
6. Submit PR

## License

MIT License - See LICENSE file

## Support

- **Issues**: GitHub Issues
- **Docs**: This repository
- **Terraform**: https://www.terraform.io/docs
- **AWS**: https://docs.aws.amazon.com/
- **Cilium**: https://docs.cilium.io/
- **EKS**: https://docs.aws.amazon.com/eks/
