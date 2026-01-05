variable "region" {
  description = "AWS region for all clusters"
  type        = string
  default     = "us-east-1"
}

variable "aws_profile" {
  description = "Optional AWS CLI profile"
  type        = string
  default     = null
}

variable "cluster_count" {
  description = "Number of EKS clusters to provision (1..50)"
  type        = number
  default     = 3
  validation {
    condition     = var.cluster_count >= 1 && var.cluster_count <= 50
    error_message = "cluster_count must be between 1 and 50."
  }
}

variable "cluster_config" {
  description = "Default configuration applied to all clusters"
  type = object({
    type         = string # mlops|inference|training|staging
    size         = string # small|medium|large|xlarge
    tenancy      = string # team/project isolation label
    compliance   = string # none|hipaa|fedramp|soc2
    auto_upgrade = bool
    version      = optional(string, "1.30")
  })
  default = {
    type         = "mlops"
    size         = "medium"
    tenancy      = "team-a"
    compliance   = "soc2"
    auto_upgrade = true
  }
}

