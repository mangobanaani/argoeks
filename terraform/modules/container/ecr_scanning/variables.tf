variable "scan_type" {
  type    = string
  default = "ENHANCED"
} # BASIC or ENHANCED
variable "rules" {
  description = "ECR registry scan rules"
  type = list(object({
    scan_frequency = string # CONTINUOUS_SCAN, SCAN_ON_PUSH, MANUAL
    filter         = string # WILDCARD pattern for repositories
  }))
  default = [
    { scan_frequency = "SCAN_ON_PUSH", filter = "*" }
  ]
}
