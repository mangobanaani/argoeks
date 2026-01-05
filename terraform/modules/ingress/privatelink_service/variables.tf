variable "name" {
  type = string
}
variable "nlb_arn" {
  type = string
}
variable "allowed_principals" {
  type    = list(string)
  default = []
}
variable "require_acceptance" {
  type    = bool
  default = true
}
variable "tags" {
  type    = map(string)
  default = {}
}
