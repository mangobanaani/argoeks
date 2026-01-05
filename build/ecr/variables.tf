variable "name" {
  description = "ECR repository name"
  type        = string
}

variable "image_tag_mutability" {
  description = "ECR tag mutability (MUTABLE or IMMUTABLE)"
  type        = string
  default     = "MUTABLE"
}

variable "scan_on_push" {
  description = "Enable ECR image scan on push"
  type        = bool
  default     = true
}

variable "kms_key_arn" {
  description = "Optional KMS key ARN for ECR encryption"
  type        = string
  default     = ""
}

variable "lifecycle_policy" {
  description = "Lifecycle policy JSON (optional)"
  type        = string
  default     = ""
}

variable "allowed_account_ids" {
  description = "AWS account IDs allowed to pull from this ECR (cross-account access)"
  type        = list(string)
  default     = []
}

variable "tags" {
  description = "Tags to apply to the repository"
  type        = map(string)
  default     = {}
}
