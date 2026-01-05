variable "region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "aws_profile" {
  description = "Optional AWS CLI profile"
  type        = string
  default     = null
}

variable "workload_account_id" {
  description = "Target workload account ID (for cross-account deployments)"
  type        = string
  default     = ""
}

variable "workload_account_role_arn" {
  description = "Role ARN Terraform should assume inside the workload account."
  type        = string
  default     = ""
}

variable "management_role_arn" {
  description = "Optional management/payer account role ARN for billing provider."
  type        = string
  default     = ""
}

variable "assume_role_external_id" {
  description = "Optional external ID required by the workload account role."
  type        = string
  default     = ""
}

variable "cluster_count" {
  description = "Number of clusters (1..50)"
  type        = number
  default     = 3
}

variable "cluster_config" {
  description = "Dev defaults"
  type = object({
    type         = string
    size         = string
    tenancy      = string
    compliance   = string
    auto_upgrade = bool
    version      = optional(string, "1.30")
  })
  default = {
    type         = "mlops"
    size         = "small"
    tenancy      = "shared"
    compliance   = "none"
    auto_upgrade = true
  }
}

variable "admin_role_arns" {

  type = list(string)

  default = []

}
variable "readonly_role_arns" {
  type    = list(string)
  default = []
}

variable "terraform_admin_role_arns" {
  description = "IAM principals (e.g., Terraform executor roles) that should automatically receive EKS access entries"
  type        = list(string)
  default     = []
}

variable "name_prefix" {

  type = string

  default = "dev-mlops"

}

# Feature flags
variable "enable_argocd" {
  type    = bool
  default = true
}
variable "enable_flux" {
  type    = bool
  default = true
}
variable "enable_thanos" {
  type    = bool
  default = true
}
variable "enable_gatekeeper" {
  type    = bool
  default = true
}
variable "enable_network_policies" {
  type    = bool
  default = true
}
variable "enable_argocd_sso" {
  type    = bool
  default = false
}
variable "enable_karpenter" {
  type    = bool
  default = true
}

variable "enable_velero" {
  description = "Enable Velero for disaster recovery backups"
  type        = bool
  default     = false
}

variable "enable_keda" {
  description = "Enable KEDA for event-driven autoscaling"
  type        = bool
  default     = false
}

variable "enable_functions" {
  type    = bool
  default = false
}
variable "enable_kserve" {
  type    = bool
  default = false
}
variable "enable_kuberay" {
  type    = bool
  default = false
}
variable "enable_kubecost" {
  type    = bool
  default = false
}
variable "enable_cloudfront" {
  type    = bool
  default = false
}
variable "enable_msk" {
  type    = bool
  default = false
}
variable "enable_amp" {
  type    = bool
  default = false
}
variable "enable_amg" {
  type    = bool
  default = false
}

variable "enable_shared_ecr" {
  description = "Enable shared ECR repository for dev images"
  type        = bool
  default     = true
}

variable "enable_cloudwatch_observability" {
  description = "Enable Amazon CloudWatch Observability EKS addon"
  type        = bool
  default     = false
}

variable "enable_aws_vpc_cni_addon" {
  description = "Deploy the AWS VPC CNI managed add-on (disable when Cilium provides networking)"
  type        = bool
  default     = false
}

variable "enable_kube_proxy_addon" {
  description = "Deploy the AWS-managed kube-proxy add-on"
  type        = bool
  default     = false
}

variable "enable_coredns_addon" {
  description = "Deploy the CoreDNS managed add-on (should stay true for cluster DNS)"
  type        = bool
  default     = true
}

variable "argocd_capability" {
  description = "AWS-managed Argo CD capability configuration"
  type = object({
    enable                       = bool
    identity_center_instance_arn = string
    admin_group_name             = string
    readonly_group_name          = string
    namespace                    = optional(string, "argocd")
    server_url                   = optional(string, null)
    network_access_type          = optional(string, "PRIVATE")
  })
  default = {
    enable                       = true
    identity_center_instance_arn = "arn:aws:sso:::instance/ssoins-xxxxxxxxxxxx"
    admin_group_name             = "platform-admins"
    readonly_group_name          = "platform-readonly"
    namespace                    = "argocd"
    server_url                   = null
    network_access_type          = "PRIVATE"
  }
}

variable "enable_guardduty_runtime" {
  description = "Enable the Amazon GuardDuty EKS Runtime Monitoring add-on"
  type        = bool
  default     = false
}

variable "enable_network_flow_monitor" {
  description = "Enable the AWS Network Flow Monitor Agent add-on"
  type        = bool
  default     = false
}

variable "enable_node_monitoring_agent" {
  description = "Enable the EKS node monitoring agent add-on"
  type        = bool
  default     = false
}

variable "enable_pod_identity_agent" {
  description = "Enable the Amazon EKS Pod Identity Agent add-on"
  type        = bool
  default     = false
}

variable "redis_existing_auth_secret_arn" {
  description = "If provided, reuse this Secrets Manager secret for the Redis auth token"
  type        = string
  default     = null
}

variable "rds_existing_secret_arn" {
  description = "If provided, reuse this Secrets Manager secret for RDS credentials"
  type        = string
  default     = null
}

variable "enable_secrets_store_provider" {
  description = "Enable the AWS Secrets Store CSI Driver provider add-on"
  type        = bool
  default     = false
}

variable "enable_hyperpod_observability" {
  description = "Enable the Amazon SageMaker HyperPod observability add-on"
  type        = bool
  default     = false
}

variable "enable_hyperpod_task_governance" {
  description = "Enable the Amazon SageMaker HyperPod task governance add-on"
  type        = bool
  default     = false
}

variable "enable_hyperpod_training_operator" {
  description = "Enable the Amazon SageMaker HyperPod training operator add-on"
  type        = bool
  default     = false
}

variable "enable_sagemaker_spaces" {
  description = "Enable the Amazon SageMaker Spaces add-on"
  type        = bool
  default     = false
}

# vLLM / Triton IRSA (optional)
variable "enable_vllm_sa_irsa" {
  type    = bool
  default = false
}
variable "vllm_namespace" {
  type    = string
  default = "vllm"
}
variable "vllm_sa_name" {
  type    = string
  default = "default"
}
variable "vllm_bucket_arn" {
  type    = string
  default = ""
}
variable "vllm_kms_arn" {
  type    = string
  default = ""
}

variable "enable_triton_sa_irsa" {

  type = bool

  default = false

}
variable "triton_namespace" {
  type    = string
  default = "triton"
}
variable "triton_sa_name" {
  type    = string
  default = "default"
}
variable "triton_bucket_arn" {
  type    = string
  default = ""
}
variable "triton_kms_arn" {
  type    = string
  default = ""
}

# Feast (optional)
variable "enable_feast" {
  type    = bool
  default = false
}
variable "enable_feast_dynamodb" {
  type    = bool
  default = false
}
variable "enable_feast_s3" {
  type    = bool
  default = false
}
variable "feast_online_table_name" {
  type    = string
  default = "dev-feast-online"
}
variable "feast_offline_bucket" {
  type    = string
  default = ""
}
variable "enable_feast_irsa" {
  type    = bool
  default = false
}
variable "feast_namespace" {
  type    = string
  default = "feast"
}
variable "feast_sa_online" {
  type    = string
  default = "feast-serving"
}
variable "feast_sa_offline" {
  type    = string
  default = "feast"
}
variable "enable_alb_alarms" {
  type    = bool
  default = false
}
variable "enable_tg_alarms" {
  type    = bool
  default = false
}
variable "enable_s3_alarms" {
  type    = bool
  default = false
}
variable "enable_security_findings" {
  type    = bool
  default = false
}

# Argo CD SSO (optional)
variable "argocd_sso_issuer" {
  type    = string
  default = ""
}
variable "argocd_sso_client_id" {
  type    = string
  default = ""
}
variable "argocd_sso_client_secret" {
  type    = string
  default = ""
}

# Argo CD service exposure
variable "argocd_service_type" {
  type    = string
  default = "LoadBalancer"
}
variable "argocd_service_annotations" {
  type    = map(string)
  default = {}
}

# Thanos S3 bucket name (optional override)
variable "thanos_bucket_name" {
  type    = string
  default = ""
}

# Flux tenants (namespaces)
variable "tenants" {
  type    = list(string)
  default = ["data-science", "ml-engineering"]
}

# Private DNS
# Route53 Private DNS Configuration
variable "private_domain" {
  description = "Private Route53 hosted zone domain (example: dev.eks.local, mycompany.internal)"
  type        = string
  default     = "dev.eks.local"  # Replace with your domain
}

variable "enable_private_dns" {
  description = "Create Route53 private hosted zone and associate with cluster VPCs"
  type        = bool
  default     = true
}

# TLS certificates (ACM Private CA ARN). If empty, skip issuing cert.
variable "acm_pca_arn" {
  type    = string
  default = ""
}
variable "argocd_host" {
  type    = string
  default = ""
}

# IRSA for app S3 access (e.g., MLflow artifacts)
variable "enable_mlflow_irsa" {
  type    = bool
  default = false
}
variable "mlflow_namespace" {
  type    = string
  default = "mlflow"
}
variable "mlflow_service_account" {
  type    = string
  default = "mlflow"
}
variable "mlflow_artifacts_bucket_arn" {
  type    = string
  default = ""
}
variable "mlflow_artifacts_kms_arn" {
  type    = string
  default = ""
}

# Databases (feature flags)
variable "enable_rds_postgres" {
  type    = bool
  default = false
}
variable "enable_redis" {
  type    = bool
  default = false
}

# RDS settings (dev defaults)
variable "rds_instance_class" {
  type    = string
  default = "db.t4g.small"
}
variable "rds_backup_retention" {
  type    = number
  default = 7
}
variable "rds_skip_final_snapshot" {
  type    = bool
  default = true
}

# IRSA for RDS IAM auth
variable "enable_rds_iam_irsa" {
  type    = bool
  default = false
}
variable "rds_iam_sa_namespace" {
  type    = string
  default = "mlflow"
}
variable "rds_iam_sa_name" {
  type    = string
  default = "mlflow"
}
## PCI/Logging/Security services
variable "enable_security_services" {
  type    = bool
  default = true
}
variable "enable_cloudtrail" {
  type    = bool
  default = true
}
variable "cloudtrail_bucket_name" {
  type    = string
  default = ""
}
variable "enable_vpc_flow_logs" {
  type    = bool
  default = true
}
variable "cw_vpc_flow_retention_days" {
  type    = number
  default = 400
}

# Central config
variable "platform_config_path" {
  type    = string
  default = "../../../configuration/platform.yaml"
}

# Kubeflow (optional)
variable "enable_kubeflow" {
  type    = bool
  default = false
}
variable "kubeflow_pipeline_bucket_arn" {
  type    = string
  default = ""
}
variable "kubeflow_pipeline_kms_arn" {
  type    = string
  default = ""
}
variable "kubeflow_namespace" {
  type    = string
  default = "kubeflow"
}
variable "kubeflow_sa_name" {
  type    = string
  default = "ml-pipeline"
}

# KServe tenants (optional IRSA for model access)
variable "kserve_tenants" {
  type = list(object({ namespace = string, service_account = string, bucket_arn = string, kms_arn = optional(string), read_only = optional(bool)
  }))
  default = []
}
## Aurora (optional)
variable "enable_aurora" {
  type    = bool
  default = false
}
variable "aurora_engine" {
  type    = string
  default = "aurora-postgresql"
}
variable "aurora_engine_version" {
  type    = string
  default = "16.2"
}
variable "aurora_serverless_v2" {
  type    = bool
  default = true
}
variable "aurora_min_acu" {
  type    = number
  default = 2
}
variable "aurora_max_acu" {
  type    = number
  default = 16
}
variable "aurora_instance_class" {
  type    = string
  default = "db.r6g.large"
}
variable "aurora_instances" {
  type    = number
  default = 2
}
variable "aurora_db_name" {
  type    = string
  default = "app"
}
variable "aurora_username" {
  type    = string
  default = "app"
}
variable "aurora_create_password_secret" {
  type    = bool
  default = true
}
variable "aurora_secret_name" {
  type    = string
  default = null
}

# ===== MLOps Stack Variables =====

variable "mlops_infrastructure" {
  description = "MLOps infrastructure components"
  type = map(object({
    enabled = bool
    config  = optional(map(any), {})
  }))
  default = {
    vpc_endpoints_mlops = { enabled = false, config = {} }
    transit_gateway     = { enabled = false, config = {} }
    network_firewall    = { enabled = false, config = {} }
    private_ca          = { enabled = false, config = {} }
    data_lake           = { enabled = false, config = {} }
    efs_mlops           = { enabled = false, config = {} }
    fsx_lustre          = { enabled = false, config = {} }
    gpu_nodes           = { enabled = false, config = {} }
  }
}

variable "mlops_data_engineering" {
  description = "Data engineering modules"
  type = map(object({
    enabled = bool
    config  = optional(map(any), {})
  }))
  default = {
    glue                    = { enabled = false, config = {} }
    athena                  = { enabled = false, config = {} }
    emr                     = { enabled = false, config = {} }
    dbt                     = { enabled = false, config = {} }
    msk                     = { enabled = false, config = {} }
    kinesis                 = { enabled = false, config = {} }
    flink                   = { enabled = false, config = {} }
    feast                   = { enabled = false, config = {} }
    sagemaker_feature_store = { enabled = false, config = {} }
    tecton                  = { enabled = false, config = {} }
    great_expectations      = { enabled = false, config = {} }
    glue_data_quality       = { enabled = false, config = {} }
    soda                    = { enabled = false, config = {} }
  }
}

variable "mlops_ml_platform" {
  description = "ML platform components with specific configuration fields"
  type = map(object({
    enabled      = bool
    rds_instance = optional(string, "db.t3.medium")
    storage_gb   = optional(number, 100)
    enable_auth  = optional(bool, true)
    config       = optional(map(any), {})
  }))
  default = {
    mlflow                = { enabled = false }
    wandb                 = { enabled = false }
    neptune               = { enabled = false }
    sagemaker_experiments = { enabled = false }
  }
}

variable "mlops_training" {
  description = "Training infrastructure"
  type = map(object({
    enabled = bool
    config  = optional(map(any), {})
  }))
  default = {
    kubeflow_training = { enabled = false, config = {} }
    ray               = { enabled = false, config = {} }
    deepspeed         = { enabled = false, config = {} }
    nemo              = { enabled = false, config = {} }
  }
}

variable "mlops_pipelines" {
  description = "Pipeline orchestration"
  type = map(object({
    enabled = bool
    config  = optional(map(any), {})
  }))
  default = {
    kubeflow_pipelines = { enabled = false, config = {} }
    airflow            = { enabled = false, config = {} }
    argo_workflows     = { enabled = false, config = {} }
    metaflow           = { enabled = false, config = {} }
  }
}

variable "mlops_governance" {
  description = "Governance and monitoring"
  type = map(object({
    enabled = bool
    config  = optional(map(any), {})
  }))
  default = {
    openlineage       = { enabled = false, config = {} }
    sagemaker_clarify = { enabled = false, config = {} }
    mlflow_lineage    = { enabled = false, config = {} }
    model_monitoring  = { enabled = false, config = {} }
    whylabs           = { enabled = false, config = {} }
    arize             = { enabled = false, config = {} }
  }
}

variable "mlops_llm" {
  description = "LLM/GenAI components"
  type = map(object({
    enabled = bool
    config  = optional(map(any), {})
  }))
  default = {
    # Vector databases
    pgvector       = { enabled = false, config = {} }
    weaviate       = { enabled = false, config = {} }
    qdrant         = { enabled = false, config = {} }
    pinecone       = { enabled = false, config = {} }
    opensearch_knn = { enabled = false, config = {} }
    # Fine-tuning
    peft    = { enabled = false, config = {} }
    axolotl = { enabled = false, config = {} }
    trl     = { enabled = false, config = {} }
    # Evaluation
    ragas           = { enabled = false, config = {} }
    deepeval        = { enabled = false, config = {} }
    trulens         = { enabled = false, config = {} }
    langchain_evals = { enabled = false, config = {} }
    # Orchestration
    langchain  = { enabled = false, config = {} }
    llamaindex = { enabled = false, config = {} }
    prompthub  = { enabled = false, config = {} }
  }
}

variable "budget_limit_usd" {
  description = "Monthly budget limit in USD"
  type        = number
  default     = 0
}

variable "budget_emails" {
  description = "Email recipients for budget alerts"
  type        = list(string)
  default     = []
}

variable "budget_thresholds" {
  description = "Budget alert thresholds in percent"
  type        = list(number)
  default     = [80, 95, 100]
}

variable "cost_center" {
  description = "Cost allocation tag (FinOps)"
  type        = string
  default     = ""
}

variable "project" {
  description = "Project tag value"
  type        = string
  default     = ""
}

variable "owner" {
  description = "Owner tag value"
  type        = string
  default     = ""
}

variable "mlflow_bucket_name" {
  description = "Override MLflow artifact bucket name"
  type        = string
  default     = ""
}

variable "feast_online_store" {
  description = "Feast online store backend (e.g., redis)"
  type        = string
  default     = "redis"
}

variable "jupyter_instance_type" {
  description = "Instance type for JupyterHub nodes"
  type        = string
  default     = "t3.large"
}

variable "jupyter_storage_gb" {
  description = "Persistent volume size per Jupyter user"
  type        = number
  default     = 50
}

variable "jupyter_idle_timeout" {
  description = "Auto-shutdown timeout (seconds) for idle notebooks"
  type        = number
  default     = 1800
}

variable "gpu_node_instance_types" {
  description = "Allowed GPU node instance types"
  type        = list(string)
  default     = []
}

variable "gpu_node_min_size" {
  description = "Minimum GPU node count"
  type        = number
  default     = 0
}

variable "gpu_node_max_size" {
  description = "Maximum GPU node count"
  type        = number
  default     = 0
}

variable "vllm_bucket_name" {
  description = "Override vLLM model bucket name"
  type        = string
  default     = ""
}

variable "vector_db_type" {
  description = "Vector database flavor (pgvector, pinecone, etc.)"
  type        = string
  default     = "pgvector"
}

variable "vector_db_size" {
  description = "Instance size for vector database"
  type        = string
  default     = "db.t3.medium"
}
