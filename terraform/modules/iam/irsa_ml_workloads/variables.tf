variable "environment" {
  description = "Environment name (dev, qa, prod)"
  type        = string
}

variable "oidc_issuer_url" {
  description = "OIDC issuer URL from EKS cluster"
  type        = string
}

variable "workloads" {
  description = "List of ML workload configurations with IRSA requirements"
  type = list(object({
    name            = string
    namespace       = string
    service_account = string

    create_namespace       = optional(bool, false)
    create_service_account = optional(bool, false)
    namespace_labels       = optional(map(string), {})

    s3_access = optional(object({
      bucket_arns  = list(string)
      kms_key_arns = optional(list(string), [])
      read_only    = optional(bool, false)
    }))

    dynamodb_access = optional(object({
      table_arns = list(string)
      read_only  = optional(bool, false)
    }))

    rds_access = optional(object({
      resource_id = string
      username    = string
    }))
  }))
  default = []

  validation {
    condition = alltrue([
      for w in var.workloads :
      can(regex("^[a-z0-9-]+$", w.name))
    ])
    error_message = "Workload names must contain only lowercase letters, numbers, and hyphens."
  }
}

variable "tags" {
  description = "Common tags to apply to all IAM resources"
  type        = map(string)
  default     = {}
}
