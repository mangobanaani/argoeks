variable "sns_topic_arn" {
  type = string
}
variable "enable_request_metrics" {
  type    = bool
  default = true
}
variable "items" {
  description = "S3 bucket alarms"
  type = list(object({
    bucket                         = optional(string)
    bucket_arn                     = optional(string)
    five_xx_threshold              = number
    four_xx_rate_threshold_percent = number
    period                         = number
    evals                          = number
  }))
}
