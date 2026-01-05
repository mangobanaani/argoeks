variable "name" {
  type = string
}
variable "oidc_issuer_url" {
  type = string
}
variable "tags" {
  type    = map(string)
  default = {}
}
variable "use_aws_managed_policy" {
  type    = bool
  default = false
}
variable "policy_json" {
  type    = string
  default = ""
}
