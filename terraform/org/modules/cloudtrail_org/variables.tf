variable "trail_name" {
  description = "Name for the organization CloudTrail."
  type        = string
  default     = "org-trail"
}

variable "bucket_name" {
  description = "Name of the S3 bucket for CloudTrail logs."
  type        = string
}

variable "create_bucket" {
  description = "Whether to create the log bucket (set false to use an existing bucket)."
  type        = bool
  default     = true
}

variable "force_destroy" {
  description = "Allow bucket destroy even if objects remain."
  type        = bool
  default     = false
}

variable "kms_key_arn" {
  description = "Optional KMS key for encrypting CloudTrail logs."
  type        = string
  default     = ""
}

variable "s3_key_prefix" {
  description = "Optional prefix within the bucket."
  type        = string
  default     = "cloudtrail"
}

variable "replica_bucket_arn" {
  description = "Optional destination bucket ARN for replication."
  type        = string
  default     = ""
}

variable "replica_kms_key_arn" {
  description = "Optional KMS key ARN for replication if replica bucket enforces SSE-KMS."
  type        = string
  default     = ""
}
