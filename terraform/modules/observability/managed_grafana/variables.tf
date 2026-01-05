variable "enabled" {
  description = "Enable Amazon Managed Grafana workspace"
  type        = bool
  default     = true
}

variable "environment" {
  description = "Environment name (dev, qa, prod)"
  type        = string
}

variable "account_access_type" {
  description = "Account access type (CURRENT_ACCOUNT or ORGANIZATION)"
  type        = string
  default     = "CURRENT_ACCOUNT"
}

variable "authentication_providers" {
  description = "Authentication providers (AWS_SSO, SAML, etc.)"
  type        = list(string)
  default     = ["AWS_SSO"]
}

variable "permission_type" {
  description = "Permission type (CUSTOMER_MANAGED or SERVICE_MANAGED)"
  type        = string
  default     = "SERVICE_MANAGED"
}

variable "data_sources" {
  description = "Data sources to enable (PROMETHEUS, CLOUDWATCH, XRAY, etc.)"
  type        = list(string)
  default     = ["PROMETHEUS", "CLOUDWATCH", "XRAY"]
}

variable "notification_destinations" {
  description = "Notification destinations (SNS, etc.)"
  type        = list(string)
  default     = ["SNS"]
}

variable "organization_role_name" {
  description = "IAM role name in organization accounts"
  type        = string
  default     = ""
}

variable "organizational_units" {
  description = "AWS Organization OUs"
  type        = list(string)
  default     = []
}

variable "role_arn" {
  description = "IAM role ARN for Grafana (if CUSTOMER_MANAGED)"
  type        = string
  default     = ""
}

variable "stack_set_name" {
  description = "CloudFormation StackSet name"
  type        = string
  default     = ""
}

variable "create_iam_role" {
  description = "Create IAM role for Grafana data source access"
  type        = bool
  default     = true
}

variable "create_api_key" {
  description = "Create API key for automation"
  type        = bool
  default     = false
}

variable "api_key_ttl" {
  description = "API key time-to-live in seconds"
  type        = number
  default     = 2592000  # 30 days
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}
