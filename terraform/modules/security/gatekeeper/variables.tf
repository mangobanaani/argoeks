variable "enabled" {
  type    = bool
  default = true
}
variable "namespace" {
  type    = string
  default = "gatekeeper-system"
}

variable "gatekeeper_chart_version" {
  description = "Helm chart version for Gatekeeper"
  type        = string
  default     = "3.16.0"
}
