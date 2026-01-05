variable "namespace" {
  type    = string
  default = "kubecost"
}
variable "install" {
  type    = bool
  default = false
}
variable "values" {
  type    = list(string)
  default = []
}

variable "kubecost_chart_version" {
  description = "Helm chart version for Kubecost cost-analyzer"
  type        = string
  default     = "2.8.5"
}
