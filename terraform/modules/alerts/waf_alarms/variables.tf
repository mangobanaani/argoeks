variable "sns_topic_arn" {
  type = string
}
variable "scope" {
  type    = string
  default = "REGIONAL"
} # REGIONAL or CLOUDFRONT
variable "items" {
  description = "List of WAF WebACL alarm configs"
  type = list(object({
    acl_name          = string
    blocked_threshold = number
    period            = number
    evals             = number
  }))
}
