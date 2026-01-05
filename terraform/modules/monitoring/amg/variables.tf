variable "account_access_type" {
  type    = string
  default = "CURRENT_ACCOUNT"
}
variable "authentication_providers" {
  type    = list(string)
  default = ["AWS_SSO"]
}
variable "permission_type" {
  type    = string
  default = "SERVICE_MANAGED"
}
variable "tags" {
  type    = map(string)
  default = {}
}
