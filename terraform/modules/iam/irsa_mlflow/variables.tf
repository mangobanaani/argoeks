variable "cluster_name" {
  description = "EKS cluster name"
  type        = string
}

variable "oidc_provider_arn" {
  description = "OIDC provider ARN for the cluster"
  type        = string
}

variable "namespace" {
  description = "Kubernetes namespace"
  type        = string
  default     = "mlflow"
}

variable "service_account" {
  description = "Kubernetes service account name"
  type        = string
  default     = "mlflow-server"
}

variable "s3_bucket_arn" {
  description = "S3 bucket ARN for MLflow artifacts"
  type        = string
}

variable "kms_key_arn" {
  description = "KMS key ARN for S3 encryption (optional)"
  type        = string
  default     = null
}

variable "enable_rds_iam_auth" {
  description = "Enable RDS IAM authentication"
  type        = bool
  default     = false
}

variable "rds_db_identifier" {
  description = "RDS database identifier (for IAM auth)"
  type        = string
  default     = ""
}

variable "rds_db_username" {
  description = "RDS database username (for IAM auth)"
  type        = string
  default     = "mlflow"
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}
