variable "name" {
  type = string
}
variable "vpc_ids" {
  type = list(string)
}
variable "tags" {
  type    = map(string)
  default = {}
}
