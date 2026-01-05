variable "environment" {
  type = string
}
variable "region" {
  type = string
}

variable "create_bucket" {
  description = "Create S3 bucket for Thanos object store"
  type        = bool
  default     = true
}

variable "bucket_name" {
  description = "If provided and create_bucket=false, use this existing bucket"
  type        = string
  default     = ""
}

variable "namespace" {

  type = string

  default = "monitoring"

}

variable "service_account_annotations" {
  description = "Annotations to add to Thanos service accounts (e.g., IRSA role)"
  type        = map(string)
  default     = {}
}

variable "enabled" {
  description = "Toggle all Thanos resources"
  type        = bool
  default     = true
}

variable "bucket_role_arns" {
  description = "Principals to allow S3 access in bucket policy"
  type        = list(string)
  default     = []
}

variable "thanos_chart_version" {
  description = "Helm chart version for Bitnami Thanos"
  type        = string
  default     = "15.8.3"
}
