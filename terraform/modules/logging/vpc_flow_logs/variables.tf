variable "vpc_id_map" {
  description = "Map of identifiers (for example, cluster names) to VPC IDs"
  type        = map(string)
}
variable "log_group_name" {
  type    = string
  default = "/aws/vpc/flow-logs"
}
variable "retention_days" {
  type    = number
  default = 400
}
