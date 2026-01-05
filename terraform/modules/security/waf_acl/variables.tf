variable "name" {
  type = string
}

variable "scope" {

  type = string

  default = "REGIONAL"

}
variable "managed_rule_groups" {
  type = list(object({ name = string, vendor = string, priority = number, override_action = optional(string, "none")
  }))
  default = [
    { name = "AWSManagedRulesCommonRuleSet", vendor = "AWS", priority = 10 },
    { name = "AWSManagedRulesKnownBadInputsRuleSet", vendor = "AWS", priority = 20 },
    { name = "AWSManagedRulesSQLiRuleSet", vendor = "AWS", priority = 30 },
    { name = "AWSManagedRulesAmazonIpReputationList", vendor = "AWS", priority = 40 }
  ]
}
variable "response_headers" {
  type    = map(string)
  default = { "Strict-Transport-Security" = "max-age=31536000; includeSubDomains" }
}

variable "tags" {

  type = map(string)

  default = {}

}
