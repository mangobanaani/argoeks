variable "enabled" {
  type    = bool
  default = true
}
variable "tenants" {
  type = list(string)
}
variable "namespace_prefix" {
  type    = string
  default = "tenant-"
}
