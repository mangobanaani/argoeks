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
variable "rds_resource_id" {
  type = string
}
variable "db_username" {
  type = string
}
variable "tags" {
  type    = map(string)
  default = {}
}
