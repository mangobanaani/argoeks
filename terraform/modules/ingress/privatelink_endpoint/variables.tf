variable "name" {
  type = string
}
variable "service_name" {
  type = string
}
variable "vpc_id" {
  type = string
}
variable "subnet_ids" {
  type = list(string)
}
variable "security_group_ids" {
  type = list(string)
}
variable "private_dns_enabled" {
  type    = bool
  default = false
}
variable "zone_id" {
  type    = string
  default = ""
}
variable "dns_name" {
  type    = string
  default = ""
}
