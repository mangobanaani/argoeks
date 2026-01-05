variable "name_prefix" {
  type = string
}
variable "sns_topic_arn" {
  type = string
}
variable "items" {
  description = "List of per-service ALB alarm configs"
  type = list(object({
    service              = string
    lb_full_name         = optional(string) # e.g., app/argocd-dev/abc123
    lb_name              = optional(string) # will be resolved to arn_suffix
    elb_5xx_threshold    = number
    elb_5xx_period       = number
    elb_5xx_evals        = number
    target_5xx_threshold = optional(number, 100)
    target_5xx_period    = optional(number, 60)
    target_5xx_evals     = optional(number, 3)
    latency_threshold    = number # seconds
    latency_stat         = string # Average or p90/p95/p99
    latency_period       = number
    latency_evals        = number
    lb_tags              = optional(map(string))
  }))
}
