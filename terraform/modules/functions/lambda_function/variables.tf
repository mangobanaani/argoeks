variable "name" {
  type = string
}
variable "artifact_path" {
  type = string
}
variable "runtime" {
  type = string
}
variable "handler" {
  type = string
}
variable "memory_size" {
  type    = number
  default = 256
}
variable "timeout" {
  type    = number
  default = 10
}
variable "architectures" {
  type    = list(string)
  default = ["x86_64"]
}
variable "environment" {
  type    = map(string)
  default = {}
}
variable "role_policy_json" {
  type    = string
  default = null
}
variable "vpc_subnet_ids" {
  type    = list(string)
  default = []
}
variable "vpc_security_group_ids" {
  type    = list(string)
  default = []
}
variable "create_http_api" {
  type    = bool
  default = false
}
variable "http_routes" {
  type    = list(string)
  default = ["GET /"]
}
variable "log_retention_days" {
  description = "CloudWatch log retention in days for this Lambda function"
  type        = number
  default     = 400
}
