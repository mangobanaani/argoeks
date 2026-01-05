variable "enabled" {
  type    = bool
  default = true
}
variable "namespaces" {
  type    = list(string)
  default = ["argocd", "flux-system", "monitoring"]
}
variable "allow_argocd_server_ingress" {
  type    = bool
  default = true
}
variable "allowed_egress_cidrs" {
  type    = list(string)
  default = []
}
variable "restrict_egress_to_https" {
  type    = bool
  default = true
}
