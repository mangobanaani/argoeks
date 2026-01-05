variable "cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
}

variable "region" {
  description = "AWS region"
  type        = string
}

variable "install" {
  description = "Whether to install Velero via Helm"
  type        = bool
  default     = true
}

variable "namespace" {
  description = "Kubernetes namespace for Velero"
  type        = string
  default     = "velero"
}

variable "velero_version" {
  description = "Velero Helm chart version"
  type        = string
  default     = "11.3.1"
}

variable "velero_plugin_version" {
  description = "Velero AWS plugin version"
  type        = string
  default     = "v1.10.0"
}

variable "create_bucket" {
  description = "Whether to create S3 bucket for backups"
  type        = bool
  default     = true
}

variable "bucket_name" {
  description = "Name of existing S3 bucket (if create_bucket = false)"
  type        = string
  default     = ""
}

variable "bucket_arn" {
  description = "ARN of existing S3 bucket (if create_bucket = false)"
  type        = string
  default     = ""
}

variable "kms_key_arn" {
  description = "ARN of existing KMS key (if create_bucket = false)"
  type        = string
  default     = ""
}

variable "backup_retention_days" {
  description = "Number of days to retain backups"
  type        = number
  default     = 30
}

variable "backup_schedules" {
  description = "Backup schedules (cron format)"
  type = map(object({
    schedule = string
    template = optional(object({
      ttl                    = optional(string)
      includedNamespaces     = optional(list(string))
      excludedNamespaces     = optional(list(string))
      includeClusterResources = optional(bool)
      snapshotVolumes        = optional(bool)
    }))
  }))
  default = {
    daily = {
      schedule = "0 2 * * *"  # 2 AM daily
      template = {
        ttl                     = "720h"  # 30 days
        includeClusterResources = true
        snapshotVolumes         = true
      }
    }
  }
}

variable "oidc_provider_arn" {
  description = "ARN of the OIDC provider for IRSA"
  type        = string
}

variable "oidc_issuer_url" {
  description = "URL of the OIDC issuer"
  type        = string
}

variable "enable_service_monitor" {
  description = "Enable Prometheus ServiceMonitor for Velero"
  type        = bool
  default     = true
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}
