variable "name" {
  type = string
}
variable "region" {
  type = string
}
variable "openapi_path" {
  type = string
}
variable "stage_name" {
  type    = string
  default = "prod"
}
variable "wafv2_acl_arn" {
  type    = string
  default = ""
}
variable "tags" {
  type    = map(string)
  default = {}
}
