variable "domain" {
  type = string
}
variable "vpc_ids" {
  type = list(string)
}
variable "region" {
  type = string
}
variable "tags" {
  type    = map(string)
  default = {}
}
variable "enabled" {
  type    = bool
  default = true
}

