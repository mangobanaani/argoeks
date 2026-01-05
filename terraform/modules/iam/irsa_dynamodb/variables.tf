variable "name" {
  type = string
}
variable "namespace" {
  type = string
}
variable "service_account" {
  type = string
}
variable "oidc_issuer_url" {
  type = string
}
variable "table_arns" {
  type = list(string)
}
variable "read_only" {
  type    = bool
  default = false
}
variable "tags" {
  type    = map(string)
  default = {}
}
