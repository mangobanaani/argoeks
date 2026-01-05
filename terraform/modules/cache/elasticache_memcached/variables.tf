variable "name" {
  type = string
}
variable "vpc_id" {
  type = string
}
variable "subnet_ids" {
  type = list(string)
}
variable "vpc_cidr" {
  type = string
}
variable "allowed_cidrs" {
  type    = list(string)
  default = []
}
variable "node_type" {
  type    = string
  default = "cache.r6g.large"
}
variable "num_cache_nodes" {
  type    = number
  default = 2
}
variable "parameter_group_name" {
  type    = string
  default = "default.memcached1.6"
}
