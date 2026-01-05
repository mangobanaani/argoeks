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
variable "bucket_arns" {
  type = list(string)
}
variable "kms_key_arns" {
  type    = list(string)
  default = []
}
variable "read_only" {
  type    = bool
  default = true
}
variable "tags" {
  type    = map(string)
  default = {}
}
