variable "enabled" {
  type    = bool
  default = true
}
variable "admin_groups" {
  type    = list(string)
  default = ["platform:admin"]
}
variable "readonly_groups" {
  type    = list(string)
  default = ["platform:readonly"]
}
variable "namespaces" {
  type    = list(string)
  default = ["default", "monitoring", "argocd", "flux-system"]
}
