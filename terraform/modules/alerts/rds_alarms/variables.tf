variable "sns_topic_arn" {
  type = string
}
variable "items" {
  description = "List of RDS alarm items"
  type = list(object({
    instance_id            = string
    period                 = number
    evals                  = number
    cpu_high_threshold     = number
    free_storage_low_mb    = number
    freeable_memory_low_mb = number
    read_latency_sec       = number
    write_latency_sec      = number
    connections_high       = number
  }))
}
