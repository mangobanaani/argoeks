# Terraform Modules

Reusable Terraform modules for building MLOps infrastructure on AWS EKS.

## Module Categories

### Core Infrastructure

#### `cluster_factory/`
**Purpose**: Creates EKS clusters with standardized configurations

**Features**:
- Multi-cluster support (1-50 clusters)
- Cilium CNI (default, replaces AWS VPC CNI)
- Karpenter node autoscaling
- Managed node groups
- OIDC provider for IRSA
- Control plane logging

**Usage**:
```hcl
module "clusters" {
  source        = "../../modules/cluster_factory"
  cluster_count = 3
  enable_cilium = true
  environment   = "dev"
}
```

#### `karpenter/`
**Purpose**: Kubernetes cluster autoscaler

**Features**:
- Just-in-time node provisioning
- Cost-optimized instance selection
- Consolidation and deprovisioning
- Spot instance support

---

### Identity & Access (IAM)

#### `iam/irsa/`
**Purpose**: Generic IRSA (IAM Roles for Service Accounts)

**Features**:
- OIDC-based authentication
- Fine-grained IAM policies
- Kubernetes service account creation

#### `iam/irsa_s3/`
**Purpose**: S3 access for workloads

**Features**:
- Bucket-specific permissions
- KMS encryption support
- Read-only or read-write access

#### `iam/irsa_ml_workloads/`
**Purpose**: Consolidated IRSA for ML workloads

**Features**:
- Multi-workload support (vLLM, Triton, Feast, MLflow, Kubeflow)
- S3 + RDS access
- Namespace creation
- Reduces 150+ lines to 40 lines

#### `iam/aws_lbc_irsa/`
**Purpose**: AWS Load Balancer Controller IRSA

#### `iam/irsa_dynamodb/`
**Purpose**: DynamoDB access for workloads

#### `iam/irsa_rds_connect/`
**Purpose**: RDS IAM authentication

---

### GitOps

#### `gitops_bootstrap/`
**Purpose**: Bootstrap GitOps tooling on clusters

**Features**:
- ArgoCD installation
- Flux installation
- AWS Load Balancer Controller
- External DNS
- SSO configuration (optional)
- Ingress with TLS

#### `gitops/flux_tenants/`
**Purpose**: Multi-tenant Flux configuration

**Features**:
- Per-tenant namespaces
- RBAC isolation
- GitOps automation

---

### Networking

#### `networking/cilium/`
**Purpose**: Install Cilium CNI

**Features**:
- eBPF-based networking
- Hubble observability
- Kube-proxy replacement
- Cluster mesh (multi-cluster)
- Network policies
- Bandwidth management

#### `networking/private_dns/`
**Purpose**: Route53 private hosted zones

#### `networking/vpc_endpoints_mlops/`
**Purpose**: VPC endpoints for ML services

**Features**:
- S3, ECR, SageMaker endpoints
- Reduced NAT costs
- Private connectivity

---

### Security

#### `security/security_services/`
**Purpose**: AWS security services

**Features**:
- Security Hub (CIS, PCI-DSS benchmarks)
- GuardDuty (threat detection)
- Inspector (vulnerability scanning)
- Macie (data discovery)

#### `security/gatekeeper/`
**Purpose**: OPA Gatekeeper policy enforcement

**Features**:
- Image registry restrictions
- Latest tag prevention
- Required labels enforcement

#### `security/waf_acl/`
**Purpose**: AWS WAF Web ACLs

**Features**:
- Managed rule groups
- DDoS protection
- Bot control

#### `security/pod_security_labels/`
**Purpose**: Pod Security Standards labels

---

### Databases

#### `db/rds_postgres/`
**Purpose**: PostgreSQL RDS instances

#### `db/aurora/`
**Purpose**: Aurora clusters (serverless or provisioned)

#### `db/aurora_global/`
**Purpose**: Multi-region Aurora global databases

---

### Storage

#### `s3/replication/`
**Purpose**: Cross-region S3 replication

#### `storage/efs/`
**Purpose**: EFS file systems for persistent storage

---

### Observability

#### `observability/thanos_aggregator/`
**Purpose**: Thanos for long-term Prometheus storage

**Features**:
- S3 object storage
- Query federation
- Downsampling
- Helm release

#### `monitoring/amp/`
**Purpose**: Amazon Managed Prometheus

#### `monitoring/amg/`
**Purpose**: Amazon Managed Grafana

---

### Alerts

#### `alerts/notifications/`
**Purpose**: SNS topics for alerts

**Features**:
- Email subscriptions
- Slack (AWS Chatbot)
- Unified alert routing

#### `alerts/alb_alarms/`
**Purpose**: ALB CloudWatch alarms

#### `alerts/rds_alarms/`
**Purpose**: RDS CloudWatch alarms

#### `alerts/s3_alarms/`
**Purpose**: S3 CloudWatch alarms

#### `alerts/budgets/`
**Purpose**: AWS Budgets for cost control

#### `alerts/security_findings/`
**Purpose**: Security Hub findings alerts

---

### ML Workloads

#### `ml/`
**Purpose**: ML-specific configurations

#### `feast/storage/`
**Purpose**: Feast feature store (S3 + DynamoDB)

#### `kuberay/operator/`
**Purpose**: Ray operator for distributed ML

#### `container/ecr/`
**Purpose**: ECR repositories for ML models

---

### Edge & CDN

#### `edge/cloudfront_distribution/`
**Purpose**: CloudFront CDN for global distribution

#### `edge/cloudfront_function/`
**Purpose**: CloudFront Functions (request/response manipulation)

---

### Ingress

#### `ingress/privatelink_endpoint/`
**Purpose**: AWS PrivateLink endpoints

#### `ingress/privatelink_service/`
**Purpose**: Expose services via PrivateLink

---

### Other

#### `config/loader/`
**Purpose**: Load YAML platform configuration

#### `functions/lambda_function/`
**Purpose**: Lambda functions with API Gateway

#### `logging/cloudtrail/`
**Purpose**: CloudTrail audit logging

#### `logging/vpc_flow_logs/`
**Purpose**: VPC flow logs to CloudWatch

#### `cost/kubecost/`
**Purpose**: Kubernetes cost monitoring

#### `kubernetes/rbac/`
**Purpose**: Kubernetes RBAC configuration

#### `kubernetes/network_policies/`
**Purpose**: NetworkPolicy resources

---

## Module Design Principles

### 1. **Single Responsibility**
Each module does one thing well

### 2. **Composable**
Modules can be combined to build complex systems

### 3. **Configurable**
Sensible defaults, extensive customization options

### 4. **Idempotent**
Safe to run multiple times

### 5. **Well-Documented**
Each module has its own README with examples

### 6. **Tested**
Validated in dev/qa/prod environments

## Usage Patterns

### Basic Module Usage

```hcl
module "example" {
  source = "../../modules/category/module_name"

  # Required parameters
  name = "my-resource"

  # Optional parameters
  tags = local.common_tags
}
```

### Module with Providers

```hcl
module "example" {
  source = "../../modules/kubernetes/something"

  providers = {
    kubernetes = kubernetes.hub
    helm       = helm.hub
  }
}
```

### Module with Count

```hcl
module "example" {
  source = "../../modules/something"
  count  = var.enable_feature ? 1 : 0

  name = "resource"
}
```

### Module with For-Each

```hcl
module "example" {
  source   = "../../modules/something"
  for_each = var.items

  name = each.key
  config = each.value
}
```

## Creating New Modules

### Module Template Structure

```
modules/new_module/
├── main.tf           # Primary resource definitions
├── variables.tf      # Input variables
├── outputs.tf        # Output values
├── versions.tf       # Provider requirements
├── README.md         # Documentation
└── examples/         # Usage examples
    └── basic/
        └── main.tf
```

### Required Files

1. **main.tf**: Resource definitions
2. **variables.tf**: All inputs
3. **outputs.tf**: All outputs
4. **README.md**: Purpose, usage, examples

### Best Practices

- Use descriptive variable names
- Provide sensible defaults
- Add validation where appropriate
- Document all variables and outputs
- Include at least one usage example
- Use consistent naming conventions
- Tag all resources

## Common Patterns

### Conditional Resources

```hcl
resource "aws_thing" "example" {
  count = var.enabled ? 1 : 0
  name  = var.name
}
```

### IRSA Pattern

```hcl
data "aws_iam_policy_document" "assume" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    principals {
      type        = "Federated"
      identifiers = ["arn:aws:iam::${data.aws_caller_identity.current.account_id}:oidc-provider/${local.issuer}"]
    }
    condition {
      test     = "StringEquals"
      variable = "${local.issuer}:sub"
      values   = ["system:serviceaccount:${var.namespace}:${var.service_account}"]
    }
  }
}
```

### Kubernetes Provider Pattern

```hcl
terraform {
  required_providers {
    kubernetes = {
      source                = "hashicorp/kubernetes"
      configuration_aliases = [kubernetes]
    }
  }
}
```

## Additional Resources

- Module source code in this directory
- Environment examples in `/terraform/environments/`
- Platform config in `/config/platform.yaml`
