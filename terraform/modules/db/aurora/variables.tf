variable "name" {
  type = string
}
variable "engine" {
  type = string
} # aurora-postgresql | aurora-mysql
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

  type = bool

  default = true

}
variable "secret_name" {
  type    = string
  default = null
}
variable "enable_iam_auth" {
  type    = bool
  default = true
}

variable "kms_key_id" {

  type = string

  default = null

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
variable "allowed_sg_ids" {
  type    = list(string)
  default = []
}

variable "deletion_protection" {

  type = bool

  default = true

}
variable "backup_retention_days" {
  type    = number
  default = 7
}
variable "preferred_backup_window" {
  type    = string
  default = null
}
variable "preferred_maintenance_window" {
  type    = string
  default = null
}
variable "apply_immediately" {
  type    = bool
  default = false
}

variable "serverless_v2" {

  type = bool

  default = false

}
variable "min_acu" {
  type    = number
  default = 2
}
variable "max_acu" {
  type    = number
  default = 16
}
variable "instance_class" {
  type    = string
  default = "db.r6g.large"
}
variable "instances" {
  type    = number
  default = 2
}
variable "monitoring_interval" {
  type    = number
  default = 0
} # enhanced monitoring seconds, 0 disables
variable "performance_insights" {
  type    = bool
  default = true
}

variable "tags" {

  type = map(string)

  default = {}
}
