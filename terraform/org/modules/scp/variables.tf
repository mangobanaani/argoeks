variable "enable_strict" {
  type    = bool
  default = false
}

variable "base_target_ids" {
  description = "Additional OU/account IDs that should always receive the baseline guardrails (root is enforced automatically)."
  type        = list(string)
  default     = []
}

variable "strict_target_ids" {
  description = "Optional stricter list of target IDs for advanced SCPs. Defaults to baseline targets when empty."
  type        = list(string)
  default     = []
}

variable "allowed_regions" {
  description = "Regions that remain enabled; all other regions are denied when strict guardrails are on."
  type        = list(string)
  default     = ["us-east-1"]
}

variable "automation_role_arns" {
  description = "Principals allowed to manage IAM access keys."
  type        = list(string)
  default     = []
}

variable "allowed_session_principals" {
  description = "Principals allowed to initiate SSM/EC2 Instance Connect sessions."
  type        = list(string)
  default     = []
}
