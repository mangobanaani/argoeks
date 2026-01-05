variable "enable_org_baseline" {
  type    = bool
  default = false
}
variable "account_definitions" {
  description = "Map of logical account keys => definition (email, ou_key, optional iam_role_name)."
  type = map(object({
    email         = string
    ou_key        = string
    name          = optional(string)
    iam_role_name = optional(string, "OrganizationAccountAccessTerraform")
    tags          = optional(map(string), {})
  }))
  default = {}
}
variable "ou_structure_override" {
  description = "Override map for OU name => parent (use \"root\" for root-level). Leave null to use repo defaults."
  type        = map(string)
  default     = null
  nullable    = true
}
variable "region" {
  type    = string
  default = "us-east-1"
}
variable "management_account_id" {
  type    = string
  default = ""
}
variable "enable_scp_strict" {
  type    = bool
  default = false
}
variable "scp_base_target_ids" {
  description = "Additional OU/account IDs to attach the baseline SCP set (root is automatic)."
  type        = list(string)
  default     = []
}
variable "scp_strict_target_ids" {
  description = "Target IDs for the strict SCP set. Defaults to baseline targets when empty."
  type        = list(string)
  default     = []
}
variable "scp_allowed_regions" {
  description = "Regions that remain enabled when the deny-region SCP is enforced."
  type        = list(string)
  default     = ["us-east-1", "us-west-2", "eu-west-1"]
}
variable "scp_automation_role_arns" {
  description = "Automation principals allowed to manage IAM access keys."
  type        = list(string)
  default     = []
}
variable "scp_allowed_session_principals" {
  description = "Principals allowed to initiate SSM/Instance Connect sessions."
  type        = list(string)
  default     = []
}
variable "enable_auto_enroll" {
  type    = bool
  default = false
}
variable "enable_config_delegation" {
  description = "Enable AWS Config delegated administrator setup."
  type        = bool
  default     = false
}
variable "log_archive_account_id" {
  description = "Optional log archive member account ID for Security Hub/GuardDuty invitations."
  type        = string
  default     = ""
}
variable "log_archive_account_email" {
  description = "Email for log archive account invitations."
  type        = string
  default     = ""
}
variable "cloudtrail_bucket_name" {
  description = "Name of the organization CloudTrail bucket."
  type        = string
  default     = ""
}
variable "cloudtrail_create_bucket" {
  type    = bool
  default = true
}
variable "cloudtrail_force_destroy" {
  type    = bool
  default = false
}
variable "cloudtrail_kms_key_arn" {
  type    = string
  default = ""
}
variable "cloudtrail_replica_bucket_arn" {
  type    = string
  default = ""
}
variable "cloudtrail_replica_kms_key_arn" {
  type    = string
  default = ""
}
