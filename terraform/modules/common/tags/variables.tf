# Cost Allocation Tags
variable "cost_center" {
  description = "Cost center for billing allocation"
  type        = string
  default     = "engineering"
}

variable "project" {
  description = "Project name for cost tracking"
  type        = string
}

variable "environment" {
  description = "Environment name (dev, qa, prod)"
  type        = string
}

variable "owner" {
  description = "Team or individual responsible for the resource"
  type        = string
  default     = "platform-team"
}

variable "application" {
  description = "Application name"
  type        = string
  default     = "argoeks"
}

# Technical Tags
variable "module_name" {
  description = "Name of the Terraform module creating this resource"
  type        = string
}

variable "git_repo" {
  description = "Git repository URL"
  type        = string
  default     = "github.com/yourorg/argoeks"
}

# Compliance Tags
variable "compliance_requirements" {
  description = "Compliance requirements (e.g., PCI-DSS, HIPAA, SOC2)"
  type        = string
  default     = "none"
}

variable "data_classification" {
  description = "Data classification level (public, internal, confidential, restricted)"
  type        = string
  default     = "internal"
}

variable "backup_policy" {
  description = "Backup policy name or schedule"
  type        = string
  default     = "standard"
}

# Additional custom tags
variable "additional_tags" {
  description = "Additional tags to merge with standard tags"
  type        = map(string)
  default     = {}
}
