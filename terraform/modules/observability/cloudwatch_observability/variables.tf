variable "enabled" {
  type    = bool
  default = true
}

variable "cluster_name" {
  type = string
}

variable "role_name" {
  type    = string
  default = "cloudwatch-observability-role"
}

variable "addon_version" {
  type    = string
  default = null
}

variable "tags" {
  type    = map(string)
  default = {}
}
