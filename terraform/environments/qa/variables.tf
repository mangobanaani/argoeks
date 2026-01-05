variable "region" {
  type    = string
  default = "us-east-1"
}

variable "aws_profile" {

  type = string

  default = null

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
  default     = 5
}

variable "cluster_config" {
  description = "QA defaults"
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
    size         = "medium"
    tenancy      = "team-qa"
    compliance   = "soc2"
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
  description = "IAM principals that should automatically get EKS access entries (leave empty to fall back to the current Terraform role)"
  type        = list(string)
  default     = []
}

variable "name_prefix" {

  type = string

  default = "qa-mlops"

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
  default = true
}
variable "enable_karpenter" {
  type    = bool
  default = true
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
  default = ["data-science", "ml-engineering", "research"]
}

# Private DNS
variable "private_domain" {
  type    = string
  default = "qa.eks.local"
}
variable "enable_private_dns" {
  type    = bool
  default = true
}

variable "enable_security_services" {

  type = bool

  default = true

}
variable "enable_cloudwatch_observability" {
  description = "Deploy CloudWatch Observability add-on (Container Insights + App Signals)"
  type        = bool
  default     = true
}

variable "cloudwatch_observability_addon_version" {
  description = "Addon version for amazon-cloudwatch-observability (leave null for latest)"
  type        = string
  default     = null
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

variable "platform_config_path" {

  type = string

  default = "../../../configuration/platform.yaml"

}

variable "acm_pca_arn" {

  type = string

  default = ""

}
variable "argocd_host" {
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

# RDS settings (qa defaults)
variable "rds_instance_class" {
  type    = string
  default = "db.m6g.large"
}
variable "rds_backup_retention" {
  type    = number
  default = 14
}
variable "rds_skip_final_snapshot" {
  type    = bool
  default = false
}
# Aurora
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
