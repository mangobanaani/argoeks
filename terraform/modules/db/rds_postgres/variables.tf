variable "name" {
  type = string
}
variable "vpc_id" {
  type = string
}
variable "subnet_ids" {
  type = list(string)
}
variable "engine_version" {
  type    = string
  default = "16.11"
}
variable "instance_class" {
  type    = string
  default = "db.t4g.small" # Cost-effective for dev ($30/mo vs $150/mo for m6g.large)
}
variable "allocated_storage" {
  type    = number
  default = 20 # Reduced for dev environment
}
variable "max_allocated_storage" {
  type    = number
  default = 1000
}
variable "multi_az" {
  type    = bool
  default = true
}
variable "backup_retention_days" {
  description = "Backup retention period in days (7 for dev, 30 for prod)"
  type        = number
  default     = 7
}
variable "deletion_protection" {
  type    = bool
  default = false # Allow easy cleanup in dev/test environments
}
variable "skip_final_snapshot" {
  type    = bool
  default = false
}
variable "performance_insights" {
  type    = bool
  default = true
}
variable "vpc_cidr" {
  type = string
}
variable "allowed_cidrs" {
  type    = list(string)
  default = []
}
variable "allowed_sg_ids" {
  type    = list(string)
  default = []
}
variable "kms_key_id" {
  type    = string
  default = null
}
variable "db_name" {
  type    = string
  default = "mlops"
}
variable "username" {
  type    = string
  default = "mlops"
}
variable "secret_name" {
  type    = string
  default = null
}
variable "enable_iam_auth" {
  type    = bool
  default = true
}
variable "require_ssl" {
  type    = bool
  default = true
}
variable "create_password_secret" {
  type    = bool
  default = true
}

variable "existing_secret_arn" {
  description = "Reuse an existing Secrets Manager secret containing the DB credentials JSON. When set, Terraform reads the password from this secret instead of creating a new one."
  type        = string
  default     = null
}
