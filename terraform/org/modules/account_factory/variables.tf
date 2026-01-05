variable "account_definitions" {
  description = "Map of logical account keys => settings (email, name, OU key, IAM role name, tags)."
  type = map(object({
    email         = string
    name          = optional(string)
    ou_key        = string
    iam_role_name = optional(string, "OrganizationAccountAccessTerraform")
    tags          = optional(map(string), {})
  }))
  default = {}
}

variable "ou_id_map" {
  description = "Map of OU key => OU ID from the OU module."
  type        = map(string)
}
