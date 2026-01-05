variable "sns_topic_arn" {
  type = string
}
variable "items" {
  description = "List of Redis alarm items"
  type = list(object({
    replication_group_id   = string
    period                 = number
    evals                  = number
    cpu_high_threshold     = number
    freeable_memory_low_mb = number
    evictions_threshold    = number
  }))
}
