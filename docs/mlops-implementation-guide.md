# MLOps Stack Implementation Guide

**Status:** Foundation Complete - Ready for Expansion

## Overview

This guide covers the MLOps stack implementation using structured configuration variables and a distributed module approach that extends your existing Terraform patterns.

## What's Been Implemented

### 1. Variable Definitions 

**Location:** `terraform/environments/{dev,qa,prod}/variables.tf`

Added 7 structured variable groups:
- `mlops_infrastructure` - Networking, storage, GPU nodes
- `mlops_data_engineering` - Batch, streaming, feature stores, data quality
- `mlops_ml_platform` - MLflow, W&B, Neptune, SageMaker Experiments
- `mlops_training` - Kubeflow, Ray, DeepSpeed, NeMo
- `mlops_pipelines` - Orchestration tools
- `mlops_governance` - Lineage, monitoring, compliance
- `mlops_llm` - Vector DBs, fine-tuning, evaluation, orchestration

**Pattern:**
```hcl
variable "mlops_ml_platform" {
  description = "ML platform components"
  type = map(object({
    enabled      = bool
    rds_instance = optional(string, "db.t3.medium")
    storage_gb   = optional(number, 100)
    enable_auth  = optional(bool, true)
    config       = optional(map(any), {})
  }))
  default = {
    mlflow = { enabled = false }
    # ... more components
  }
}
```

### 2. Terraform Modules 

**Created Modules:**

#### Networking
- `terraform/modules/networking/vpc_endpoints_mlops/`
  - SageMaker API, SageMaker Runtime, Bedrock Runtime endpoints
  - Security group for VPC endpoints
  - Eliminates NAT costs for ML API calls

#### Storage
- `terraform/modules/storage/data_lake/`
  - S3 bucket with zones: raw/, processed/, features/, models/, artifacts/
  - KMS encryption, versioning, lifecycle policies
  - Optional cross-region replication
  - Public access block

#### ML Platform
- `terraform/modules/ml/mlflow/tracking_server/`
  - RDS Postgres for metadata
  - S3 bucket for artifacts
  - Secrets Manager for credentials
  - Multi-AZ support (configurable)

#### IAM
- `terraform/modules/iam/irsa_mlflow/`
  - IRSA role for MLflow ServiceAccount
  - S3 access policy for artifacts
  - Optional RDS IAM authentication

### 3. Example Configuration 

**Location:** `terraform/environments/dev/terraform.tfvars.example`

Comprehensive example showing:
- How to enable/disable each module
- Configuration options per module
- Dev-specific sizing (smaller RDS, fewer resources)
- Comments explaining choices

### 4. Design Documentation 

**Location:** `docs/plans/2026-01-01-mlops-stack-design.md`

Complete architectural design with:
- Module structure rationale
- Variable organization
- All ~50 planned modules
- Implementation phases
- Cost estimates
- Security considerations

## How to Use What's Built

### Step 0: Bootstrap AWS Organizations (Multi-Account Ready)

1. Populate `org/account_map.auto.tfvars` with one entry per account (shared services, data, training, serving, experiments, sandbox). Map each entry to an OU key defined in `org/locals.tf`.
2. (Optional) Override the OU hierarchy via `ou_structure_override` if your Organization already has a preferred layout.
3. Run the baseline:
   ```bash
   cd org
   terraform init
   terraform apply
   ```
   This provisions OUs, accounts, SCPs (TLS-only, deny unsupported regions, block unauthorized SSM/Instance Connect, deny manual IAM access keys), delegated Security Hub / GuardDuty / Config admins, and an org-wide CloudTrail bucket.
4. Copy the `module.accounts[0].accounts` output and paste the relevant `assume_role_arn` into each environment’s `terraform.tfvars` (`workload_account_role_arn`, `workload_account_id`, `management_role_arn`, `assume_role_external_id`).
5. Verify with:
   ```bash
   aws organizations list-accounts
   aws organizations list-policies-for-target --target-id <account-id> --filter SERVICE_CONTROL_POLICY
   ```
6. Follow `docs/runbooks/multi-account.md` whenever you add accounts, rotate automation roles, or need to validate guardrails.

### Step 1: Enable Basic MLOps Infrastructure

Create `terraform/environments/dev/terraform.tfvars`:

```hcl
# Enable VPC endpoints for ML services
mlops_infrastructure = {
  vpc_endpoints_mlops = {
    enabled = true
    config  = {}
  }

  data_lake = {
    enabled = true
    config  = {
      enable_versioning = true
      lifecycle_rules   = true
    }
  }

  # Disable expensive components in dev
  gpu_nodes       = { enabled = false, config = {} }
  fsx_lustre      = { enabled = false, config = {} }
  transit_gateway = { enabled = false, config = {} }
  network_firewall = { enabled = false, config = {} }
  private_ca      = { enabled = false, config = {} }
  efs_mlops       = { enabled = false, config = {} }
}

# Enable MLflow
mlops_ml_platform = {
  mlflow = {
    enabled      = true
    rds_instance = "db.t3.small"
    storage_gb   = 50
    enable_auth  = false
    config       = {
      multi_az = false
    }
  }

  wandb                 = { enabled = false }
  neptune               = { enabled = false }
  sagemaker_experiments = { enabled = false }
}

# Start with other modules disabled
mlops_data_engineering = {
  glue                    = { enabled = false, config = {} }
  athena                  = { enabled = false, config = {} }
  # ... (all disabled for now)
}

mlops_training = {
  kubeflow_training = { enabled = false, config = {} }
  # ... (all disabled)
}

mlops_pipelines = {
  kubeflow_pipelines = { enabled = false, config = {} }
  # ... (all disabled)
}

mlops_governance = {
  openlineage = { enabled = false, config = {} }
  # ... (all disabled)
}

mlops_llm = {
  pgvector = { enabled = false, config = {} }
  # ... (all disabled)
}
```

### Step 2: Add Module Invocations

In `terraform/environments/dev/main.tf`, add:

```hcl
# Data sources for common resources
data "aws_kms_key" "data" {
  key_id = "alias/data-encryption"
}

# VPC Endpoints for MLOps
module "vpc_endpoints_mlops" {
  source = "../../modules/networking/vpc_endpoints_mlops"
  count  = var.mlops_infrastructure["vpc_endpoints_mlops"].enabled ? 1 : 0

  region              = var.region
  vpc_id              = module.cluster_factory.vpc_id
  vpc_cidr            = module.cluster_factory.vpc_cidr
  private_subnet_ids  = module.cluster_factory.private_subnet_ids
  name_prefix         = var.name_prefix

  tags = local.common_tags
}

# S3 Data Lake
module "data_lake" {
  source = "../../modules/storage/data_lake"
  count  = var.mlops_infrastructure["data_lake"].enabled ? 1 : 0

  bucket_prefix       = var.name_prefix
  kms_key_arn         = data.aws_kms_key.data.arn
  enable_versioning   = lookup(var.mlops_infrastructure["data_lake"].config, "enable_versioning", true)
  lifecycle_rules     = lookup(var.mlops_infrastructure["data_lake"].config, "lifecycle_rules", true)
  enable_replication  = lookup(var.mlops_infrastructure["data_lake"].config, "enable_replication", false)
  replication_region  = lookup(var.mlops_infrastructure["data_lake"].config, "replication_region", null)

  tags = local.common_tags
}

# MLflow Tracking Server
module "mlflow_infrastructure" {
  source = "../../modules/ml/mlflow/tracking_server"
  count  = var.mlops_ml_platform["mlflow"].enabled ? 1 : 0

  name_prefix        = var.name_prefix
  vpc_id             = module.cluster_factory.vpc_id
  vpc_cidr           = module.cluster_factory.vpc_cidr
  subnet_ids         = module.cluster_factory.private_subnet_ids
  rds_instance_class = var.mlops_ml_platform["mlflow"].rds_instance
  storage_gb         = var.mlops_ml_platform["mlflow"].storage_gb
  multi_az           = lookup(var.mlops_ml_platform["mlflow"].config, "multi_az", false)
  kms_key_arn        = data.aws_kms_key.data.arn

  tags = local.common_tags
}

# IRSA for MLflow
module "irsa_mlflow" {
  source = "../../modules/iam/irsa_mlflow"
  count  = var.mlops_ml_platform["mlflow"].enabled ? 1 : 0

  cluster_name      = module.cluster_factory.cluster_name
  oidc_provider_arn = module.cluster_factory.oidc_provider_arn
  namespace         = "mlflow"
  service_account   = "mlflow-server"
  s3_bucket_arn     = module.mlflow_infrastructure[0].artifact_bucket_arn
  kms_key_arn       = data.aws_kms_key.data.arn

  tags = local.common_tags
}
```

### Step 3: Apply Infrastructure

```bash
cd terraform/environments/dev
terraform init
terraform plan
terraform apply
```

### Step 4: Deploy MLflow to Kubernetes

Create `platform/mlflow/base/kustomization.yaml`:

```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

namespace: mlflow

resources:
  - namespace.yaml
  - serviceaccount.yaml
  - deployment.yaml
  - service.yaml
  - ingress.yaml
```

Create `platform/mlflow/base/namespace.yaml`:

```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: mlflow
  labels:
    name: mlflow
    app.kubernetes.io/name: mlflow
```

Create `platform/mlflow/base/serviceaccount.yaml`:

```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: mlflow-server
  namespace: mlflow
  annotations:
    # This will be set by Terraform output
    eks.amazonaws.com/role-arn: arn:aws:iam::ACCOUNT_ID:role/ROLE_NAME
```

Create `platform/mlflow/base/deployment.yaml`:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: mlflow-server
  namespace: mlflow
  labels:
    app: mlflow
spec:
  replicas: 2
  selector:
    matchLabels:
      app: mlflow
  template:
    metadata:
      labels:
        app: mlflow
    spec:
      serviceAccountName: mlflow-server
      containers:
      - name: mlflow
        image: ghcr.io/mlflow/mlflow:v2.9.2
        ports:
        - containerPort: 5000
          name: http
        env:
        - name: MLFLOW_BACKEND_STORE_URI
          value: "postgresql://USER:PASS@RDS_ENDPOINT:5432/mlflow"
        - name: MLFLOW_DEFAULT_ARTIFACT_ROOT
          value: "s3://BUCKET_NAME/artifacts"
        - name: AWS_DEFAULT_REGION
          value: "us-east-1"
        resources:
          requests:
            cpu: 500m
            memory: 1Gi
          limits:
            cpu: 2000m
            memory: 4Gi
        livenessProbe:
          httpGet:
            path: /health
            port: 5000
          initialDelaySeconds: 30
          periodSeconds: 10
        readinessProbe:
          httpGet:
            path: /health
            port: 5000
          initialDelaySeconds: 15
          periodSeconds: 5
```

## What Remains to Be Built

### Core Infrastructure (High Priority)

**Networking Modules:**
1. `terraform/modules/networking/transit_gateway/` - Multi-VPC connectivity
2. `terraform/modules/networking/network_firewall/` - Traffic inspection
3. `terraform/modules/networking/private_ca/` - Internal TLS CA

**Storage Modules:**
3. `terraform/modules/storage/efs_mlops/` - Shared filesystem
4. `terraform/modules/storage/fsx_lustre/` - HPC storage

**Compute Modules:**
5. `terraform/modules/ml/training/gpu_nodepool/` - Karpenter GPU nodes

### Data Engineering (High Priority)

**Batch Processing:**
1. `terraform/modules/data/glue/` - ETL jobs, Data Catalog
2. `terraform/modules/data/athena/` - SQL queries
3. `terraform/modules/data/emr/` - Spark clusters
4. `terraform/modules/data/dbt/` - dbt deployment

**Streaming:**
5. `terraform/modules/data/kinesis/` - Kinesis streams
6. `terraform/modules/data/flink/` - Stream processing

**Feature Stores:**
7. Extend `terraform/modules/feast/registry/` - Feast registry
8. Extend `terraform/modules/feast/server/` - Feast server
9. `terraform/modules/ml/sagemaker/feature_store/` - SageMaker FS

**Data Quality:**
10. `terraform/modules/data/glue_data_quality/` - Glue quality rules
11. Platform manifests: `platform/data-quality/great-expectations/`
12. Platform manifests: `platform/data-quality/soda/`

### Phase 3: ML Platform Extensions (Medium Priority)

**Experiment Tracking:**
1. Platform manifests: `platform/wandb/` - W&B deployment
2. `terraform/modules/ml/sagemaker/experiments/` - SageMaker Experiments

**Training:**
3. `terraform/modules/ml/training/kubeflow_operator/` - Kubeflow Training
4. Extend `terraform/modules/kuberay/cluster_template/` - Ray templates
5. Platform manifests: `platform/kubeflow/training/` - Training operators
6. Platform manifests: `platform/deepspeed/` - DeepSpeed configs
7. Platform manifests: `platform/nemo/` - NeMo configs

**Pipelines:**
8. Platform manifests: `platform/kubeflow/pipelines/` - KFP deployment
9. Platform manifests: `platform/airflow/` - Airflow on EKS
10. Platform manifests: `platform/argo-workflows/` - Argo Workflows
11. `terraform/modules/ml/metaflow/` - Metaflow infrastructure

### Phase 4: Observability & Governance (Medium Priority)

**Monitoring:**
1. `terraform/modules/ml/governance/model_monitoring/` - Evidently infrastructure
2. `terraform/modules/monitoring/ml_dashboards/` - Grafana dashboards
3. Platform manifests: `platform/observability/evidently/`

**Governance:**
4. `terraform/modules/ml/governance/openlineage/` - Lineage infrastructure
5. `terraform/modules/ml/sagemaker/clarify/` - Bias detection
6. Platform manifests: `platform/governance/openlineage/`

**Cost Management:**
7. `terraform/modules/cost/ml_budgets/` - GPU budgets
8. `terraform/modules/security/ml_policies/` - Gatekeeper policies

### Phase 5: LLM/GenAI (Medium Priority)

**Vector Databases:**
1. `terraform/modules/db/pgvector/` - Postgres with vector extension
2. Platform manifests: `platform/vector-dbs/weaviate/`
3. Platform manifests: `platform/vector-dbs/qdrant/`
4. Platform manifests: `platform/vector-dbs/opensearch-knn/`

**Fine-tuning & Evaluation:**
5. Platform manifests: `platform/llm/fine-tuning/peft/`
6. Platform manifests: `platform/llm/fine-tuning/axolotl/`
7. Platform manifests: `platform/llm/evaluation/ragas/`
8. Platform manifests: `platform/llm/evaluation/deepeval/`

**Orchestration:**
9. Platform manifests: `platform/llm/orchestration/langchain/`
10. Platform manifests: `platform/llm/orchestration/llamaindex/`

### Phase 6: Additional IRSA Modules (Ongoing)

Create IRSA modules for all components that need AWS access:
1. `terraform/modules/iam/irsa_feast/` (already exists, extend as needed)
2. `terraform/modules/iam/irsa_ray/`
3. `terraform/modules/iam/irsa_kubeflow/`
4. `terraform/modules/iam/irsa_model_serving/`
5. `terraform/modules/iam/irsa_glue/`
6. `terraform/modules/iam/irsa_emr/`
7. `terraform/modules/iam/irsa_vector_db/`

### Phase 7: ArgoCD ApplicationSets (Final Integration)

Create ApplicationSets for fleet-wide deployment:
1. `gitops/argocd/applicationset-mlops-training.yaml`
2. `gitops/argocd/applicationset-mlops-pipelines.yaml`
3. `gitops/argocd/applicationset-mlops-monitoring.yaml`
4. `gitops/argocd/applicationset-mlops-governance.yaml`
5. `gitops/argocd/applicationset-mlops-llm.yaml`
6. `gitops/argocd/applicationset-feast.yaml`
7. `gitops/argocd/applicationset-data-quality.yaml`

## Module Template

When creating new modules, follow this template:

### Terraform Module Structure

```
terraform/modules/category/module_name/
├── main.tf       # Resource definitions
├── variables.tf  # Input variables
└── outputs.tf    # Output values
```

### Example: Creating Glue Module

**File:** `terraform/modules/data/glue/main.tf`

```hcl
resource "aws_glue_catalog_database" "mlops" {
  name = "${var.catalog_name}-database"

  tags = var.tags
}

resource "aws_glue_crawler" "s3_data" {
  count = var.enable_crawler ? 1 : 0

  database_name = aws_glue_catalog_database.mlops.name
  name          = "${var.catalog_name}-s3-crawler"
  role          = aws_iam_role.glue.arn

  s3_target {
    path = "s3://${var.data_lake_bucket}/processed/"
  }

  tags = var.tags
}

resource "aws_iam_role" "glue" {
  name = "${var.catalog_name}-glue-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "glue.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "glue_service" {
  role       = aws_iam_role.glue.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSGlueServiceRole"
}

# Add S3 access policy, KMS access, etc.
```

**File:** `terraform/modules/data/glue/variables.tf`

```hcl
variable "catalog_name" {
  description = "Glue catalog name prefix"
  type        = string
}

variable "data_lake_bucket" {
  description = "S3 data lake bucket name"
  type        = string
}

variable "enable_crawler" {
  description = "Enable Glue crawler"
  type        = bool
  default     = true
}

variable "kms_key_arn" {
  description = "KMS key ARN for encryption"
  type        = string
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}
```

**File:** `terraform/modules/data/glue/outputs.tf`

```hcl
output "database_name" {
  description = "Glue database name"
  value       = aws_glue_catalog_database.mlops.name
}

output "role_arn" {
  description = "Glue IAM role ARN"
  value       = aws_iam_role.glue.arn
}
```

### Usage in Environment

**File:** `terraform/environments/dev/main.tf`

```hcl
module "glue_catalog" {
  source = "../../modules/data/glue"
  count  = var.mlops_data_engineering["glue"].enabled ? 1 : 0

  catalog_name      = "${var.name_prefix}-mlops"
  data_lake_bucket  = module.data_lake[0].bucket_name
  enable_crawler    = lookup(var.mlops_data_engineering["glue"].config, "enable_crawler", true)
  kms_key_arn       = data.aws_kms_key.data.arn

  tags = local.common_tags
}
```

## Testing Strategy

### 1. Module Validation

```bash
cd terraform/modules/networking/vpc_endpoints_mlops
terraform init
terraform validate
```

### 2. Environment Plan

```bash
cd terraform/environments/dev
terraform plan -out=plan.out
```

### 3. Gradual Apply

Enable one module at a time:

```bash
# First apply: VPC endpoints only
terraform apply -target=module.vpc_endpoints_mlops

# Second apply: Data lake
terraform apply -target=module.data_lake

# Third apply: MLflow
terraform apply -target=module.mlflow_infrastructure
terraform apply -target=module.irsa_mlflow
```

### 4. Platform Deployment

After Terraform creates infrastructure:

```bash
# Apply MLflow platform manifests
kubectl apply -k platform/mlflow/overlays/dev/
```

## Best Practices

### 1. Always Use Structured Config

 **Good:**
```hcl
mlops_ml_platform = {
  mlflow = {
    enabled      = true
    rds_instance = "db.t3.small"
    storage_gb   = 50
    config       = { multi_az = false }
  }
}
```

 **Bad:**
```hcl
enable_mlflow = true
mlflow_rds_instance = "db.t3.small"
mlflow_storage_gb = 50
mlflow_multi_az = false
```

### 2. Use lookup() for Config Values

```hcl
multi_az = lookup(var.mlops_ml_platform["mlflow"].config, "multi_az", false)
```

This provides defaults when config keys aren't specified.

### 3. Conditional Module Creation

Always use count for optional modules:

```hcl
module "mlflow_infrastructure" {
  source = "../../modules/ml/mlflow/tracking_server"
  count  = var.mlops_ml_platform["mlflow"].enabled ? 1 : 0
  # ... config
}
```

### 4. Reference Module Outputs Safely

```hcl
s3_bucket_arn = module.mlflow_infrastructure[0].artifact_bucket_arn
```

Use `[0]` since module has `count`.

### 5. Tag Everything

```hcl
tags = merge(
  var.tags,
  {
    Name      = "${var.name_prefix}-resource"
    Component = "MLflow"
    ManagedBy = "Terraform"
  }
)
```

## Next Steps

1. **Review the design document:** `docs/plans/2026-01-01-mlops-stack-design.md`

2. **Choose your starting point:**
   - **Quick win:** Deploy VPC endpoints + Data Lake + MLflow
   - **Data focus:** Add Glue, Athena, Feast
   - **Training focus:** Add GPU nodes, Ray, Kubeflow
   - **GenAI focus:** Add pgvector, LangChain, evaluation tools

3. **Implement incrementally:**
   - Create one module at a time
   - Test in dev environment
   - Document learnings
   - Expand to qa/prod

4. **Build platform manifests:**
   - Start with MLflow (example provided)
   - Follow same pattern for other tools
   - Use Kustomize overlays for env-specific config

5. **Create ApplicationSets:**
   - Deploy platform components fleet-wide
   - Use cluster registry for targeting
   - Leverage ArgoCD for GitOps

## Troubleshooting

### Module Not Found

**Error:** `Module not found: terraform/modules/ml/mlflow/tracking_server`

**Solution:** Ensure module exists and path is correct. Run `terraform init` after adding new modules.

### Variable Type Mismatch

**Error:** `Invalid value for variable "mlops_ml_platform"`

**Solution:** Check that all enabled modules have the required fields. Use the example .tfvars as a reference.

### IRSA Not Working

**Symptom:** Pods can't access S3 or RDS

**Check:**
1. ServiceAccount has correct annotation
2. OIDC provider is configured
3. Trust relationship in IAM role is correct
4. Pods are using the correct ServiceAccount

### Circular Dependencies

**Error:** `Cycle: module.A depends on module.B which depends on module.A`

**Solution:** Use data sources or pass outputs explicitly. Avoid mutual dependencies.

## Support

For issues or questions:
1. Check the design document
2. Review existing module examples
3. Consult Terraform documentation
4. Ask the platform team

## Summary

**What's Ready:**
-  All variable definitions (7 categories, ~50 modules)
-  VPC endpoints for ML services
-  S3 data lake with zones and lifecycle
-  MLflow tracking server (RDS + S3)
-  IRSA for MLflow
-  Example configuration
-  Comprehensive design document

**What's Next:**
- Build remaining Terraform modules (~40 more)
- Create platform manifests (Kubernetes YAMLs)
- Create ArgoCD ApplicationSets
- Integrate into environment main.tf files

**Estimated Effort:**
- Core infrastructure: 1-2 weeks
- Data engineering: 1-2 weeks
- ML platform: 1-2 weeks
- Observability: 1 week
- LLM/GenAI: 1 week
- Testing & documentation: 1 week

**Total:** 6-10 weeks for complete implementation

The foundation is solid. Follow the patterns established in the existing modules to build out the rest of the stack incrementally.
