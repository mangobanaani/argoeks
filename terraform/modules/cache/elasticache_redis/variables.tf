variable "name" {
  type = string
}
variable "vpc_id" {
  type = string
}
variable "subnet_ids" {
  type = list(string)
}
variable "vpc_cidr" {
  type = string
}
variable "allowed_cidrs" {
  type    = list(string)
  default = []
}
variable "node_type" {
  type    = string
  default = "cache.t4g.small" # Cost-effective for dev ($24/mo vs $120/mo for r6g.large)
}
variable "replicas_per_node_group" {
  type    = number
  default = 1
}
variable "multi_az_enabled" {
  type    = bool
  default = true
}
variable "engine_version" {
  type    = string
  default = "7.1"
}
variable "kms_key_id" {
  type    = string
  default = null
}
variable "auth_token_secret_name" {
  type    = string
  default = null
}

variable "existing_auth_secret_arn" {
  description = "Reuse an existing Secrets Manager secret containing {\"auth_token\":\"...\"}. If set, Terraform will read and reuse the auth token instead of creating a new secret."
  type        = string
  default     = null
}
