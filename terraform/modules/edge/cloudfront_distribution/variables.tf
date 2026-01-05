variable "aliases" {
  type    = list(string)
  default = []
}
variable "acm_cert_arn" {
  type = string
}
variable "price_class" {
  type    = string
  default = "PriceClass_100"
}
variable "enabled" {
  type    = bool
  default = true
}
variable "comment" {
  type    = string
  default = ""
}
variable "default_root_object" {
  type    = string
  default = ""
}
variable "wafv2_acl_arn" {
  type    = string
  default = ""
}

variable "origins" {
  description = "Origin list"
  type = list(object({
    id              = string
    type            = string # "s3" | "alb" | "custom"
    domain_name     = string
    origin_path     = optional(string)
    protocol_policy = optional(string, "https-only")
  }))
}

variable "behaviors" {
  description = "Cache behaviors"
  type = list(object({
    path_pattern             = string
    origin_id                = string
    viewer_protocol_policy   = string # allow-all | https-only | redirect-to-https
    allowed_methods          = list(string)
    cached_methods           = list(string)
    compress                 = optional(bool, true)
    cache_policy_id          = optional(string)
    origin_request_policy_id = optional(string)
    function_associations    = optional(list(object({ event_type = string, function_arn = string })), [])
    is_default               = optional(bool, false)
  }))
}
