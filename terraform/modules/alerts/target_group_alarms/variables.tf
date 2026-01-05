variable "sns_topic_arn" {
  type = string
}
variable "items" {
  description = "Target group alarms"
  type = list(object({
    service       = string
    lb_full_name  = optional(string) # app/<lb>/<id> or net/<lb>/<id>
    lb_name       = optional(string)
    tg_full_name  = optional(string) # targetgroup/<name>/<id>
    tg_name       = optional(string)
    healthy_min   = number # minimum healthy hosts
    unhealthy_max = number # max unhealthy hosts
    period        = number
    evals         = number
  }))
}
