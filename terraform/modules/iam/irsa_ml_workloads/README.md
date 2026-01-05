# IRSA ML Workloads Module

Composite module for creating IRSA roles and Kubernetes resources for multiple ML workloads in a single declaration. Reduces repetition when configuring similar workloads like MLflow, vLLM, Triton, Feast, etc.

## Features

- Creates IRSA roles for S3, DynamoDB, and RDS access
- Optionally creates Kubernetes namespaces and service accounts
- Supports multiple workloads in one module call
- Automatic annotation of service accounts with IAM role ARNs

## Usage

### Basic example

```hcl
module "ml_workloads" {
  source = "../../modules/iam/irsa_ml_workloads"

  environment     = "dev"
  oidc_issuer_url = data.aws_eks_cluster.hub.identity[0].oidc[0].issuer

  workloads = [
    {
      name                   = "mlflow"
      namespace              = "mlops"
      service_account        = "mlflow"
      create_namespace       = true
      create_service_account = true

      s3_access = {
        bucket_arns  = ["arn:aws:s3:::mlflow-artifacts"]
        kms_key_arns = ["arn:aws:kms:us-east-1:123456789012:key/abc-123"]
        read_only    = false
      }

      rds_access = {
        resource_id = "db-ABCD1234567890"
        username    = "mlflow"
      }
    },
    {
      name                   = "vllm"
      namespace              = "inference"
      service_account        = "vllm"
      create_namespace       = false
      create_service_account = true

      s3_access = {
        bucket_arns = ["arn:aws:s3:::model-storage"]
        read_only   = true
      }
    }
  ]

  tags = {
    environment = "dev"
    managed_by  = "terraform"
  }
}
```

### Replacing individual IRSA modules

**Before** (repetitive pattern):

```hcl
module "irsa_vllm" {
  source          = "../../modules/iam/irsa_s3"
  name            = "dev-vllm-irsa"
  namespace       = "inference"
  service_account = "vllm"
  oidc_issuer_url = data.aws_eks_cluster.hub.identity[0].oidc[0].issuer
  bucket_arns     = ["arn:aws:s3:::models"]
  read_only       = false
}

resource "kubernetes_namespace_v1" "vllm" {
  metadata { name = "inference" }
}

resource "kubernetes_service_account_v1" "vllm" {
  metadata {
    name        = "vllm"
    namespace   = "inference"
    annotations = module.irsa_vllm.annotations
  }
  depends_on = [kubernetes_namespace_v1.vllm]
}

module "irsa_triton" {
  source          = "../../modules/iam/irsa_s3"
  name            = "dev-triton-irsa"
  namespace       = "inference"
  service_account = "triton"
  oidc_issuer_url = data.aws_eks_cluster.hub.identity[0].oidc[0].issuer
  bucket_arns     = ["arn:aws:s3:::models"]
  read_only       = false
}

resource "kubernetes_service_account_v1" "triton" {
  metadata {
    name        = "triton"
    namespace   = "inference"
    annotations = module.irsa_triton.annotations
  }
  depends_on = [kubernetes_namespace_v1.vllm]
}
```

**After** (consolidated pattern):

```hcl
module "inference_workloads" {
  source = "../../modules/iam/irsa_ml_workloads"

  environment     = "dev"
  oidc_issuer_url = data.aws_eks_cluster.hub.identity[0].oidc[0].issuer

  workloads = [
    {
      name                   = "vllm"
      namespace              = "inference"
      service_account        = "vllm"
      create_namespace       = true
      create_service_account = true
      s3_access              = {
        bucket_arns = ["arn:aws:s3:::models"]
        read_only   = false
      }
    },
    {
      name                   = "triton"
      namespace              = "inference"
      service_account        = "triton"
      create_service_account = true
      s3_access              = {
        bucket_arns = ["arn:aws:s3:::models"]
        read_only   = false
      }
    }
  ]
}
```

## Inputs

| Name | Description | Type | Required |
|------|-------------|------|----------|
| environment | Environment name | string | yes |
| oidc_issuer_url | OIDC issuer URL from EKS | string | yes |
| workloads | List of workload configurations | list(object) | no |
| tags | Common tags for IAM resources | map(string) | no |

## Outputs

| Name | Description |
|------|-------------|
| s3_role_arns | Map of S3 access role ARNs by workload |
| dynamodb_role_arns | Map of DynamoDB access role ARNs by workload |
| rds_role_arns | Map of RDS access role ARNs by workload |
| all_role_arns | Complete map of all role ARNs |
| service_accounts | Map of created service accounts |
| namespaces | List of created namespaces |

## Workload Configuration

Each workload in the `workloads` list supports:

- `name`: Workload identifier (used in IAM role naming)
- `namespace`: Kubernetes namespace
- `service_account`: Kubernetes service account name
- `create_namespace`: Whether to create the namespace (default: false)
- `create_service_account`: Whether to create the service account (default: false)
- `namespace_labels`: Additional labels for the namespace (optional)
- `s3_access`: S3 access configuration (optional)
  - `bucket_arns`: List of S3 bucket ARNs
  - `kms_key_arns`: List of KMS key ARNs for encryption (optional)
  - `read_only`: Whether access is read-only (default: false)
- `dynamodb_access`: DynamoDB access configuration (optional)
  - `table_arns`: List of DynamoDB table ARNs
  - `read_only`: Whether access is read-only (default: false)
- `rds_access`: RDS IAM authentication configuration (optional)
  - `resource_id`: RDS resource identifier
  - `username`: Database username

## Notes

- At least one of `s3_access`, `dynamodb_access`, or `rds_access` must be specified for each workload
- Workload names must contain only lowercase letters, numbers, and hyphens
- If `create_namespace` is false, the namespace must already exist
- Service account annotations are automatically merged from all configured access types
