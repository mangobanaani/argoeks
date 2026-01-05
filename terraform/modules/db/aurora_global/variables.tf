variable "name" {
  type = string
}
variable "engine" {
  type = string
}
variable "engine_version" {
  type = string
}
variable "database_name" {
  type    = string
  default = "app"
}
variable "username" {
  type    = string
  default = "app"
}
variable "create_password_secret" {
  type    = bool
  default = true
}
variable "secret_name" {
  type    = string
  default = null
}

variable "primary" {
  type = object({
    vpc_id         = string
    subnet_ids     = list(string)
    vpc_cidr       = string
    kms_key_id     = optional(string)
    serverless_v2  = optional(bool, true)
    min_acu        = optional(number, 2)
    max_acu        = optional(number, 16)
    instance_class = optional(string, "db.r6g.large")
    instances      = optional(number, 2)
  })
}

variable "secondary" {
  type = object({
    vpc_id         = string
    subnet_ids     = list(string)
    vpc_cidr       = string
    kms_key_id     = optional(string)
    serverless_v2  = optional(bool, true)
    min_acu        = optional(number, 2)
    max_acu        = optional(number, 16)
    instance_class = optional(string, "db.r6g.large")
    instances      = optional(number, 2)
  })
}

variable "tags" {

  type = map(string)

  default = {}
}
