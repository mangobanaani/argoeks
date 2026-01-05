variable "namespace" {
  type    = string
  default = "ingress-nginx"
}
variable "install" {
  type    = bool
  default = false
}
variable "values" {
  type    = list(string)
  default = []
}
variable "chart_version" {
  type    = string
  default = null
}
