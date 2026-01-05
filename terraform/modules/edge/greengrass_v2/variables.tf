variable "thing_group_name" {
  type = string
}
variable "create_token_exchange_role" {
  type    = bool
  default = true
}
variable "tags" {
  type    = map(string)
  default = {}
}
