variable "name" {
  type = string
}
variable "kafka_version" {
  type    = string
  default = "3.6.0"
}
variable "number_of_broker_nodes" {
  type    = number
  default = 3
}
variable "broker_instance_type" {
  type    = string
  default = "kafka.m5.large"
}
variable "vpc_id" {
  type = string
}
variable "subnet_ids" {
  type = list(string)
}
variable "security_group_ids" {
  type    = list(string)
  default = []
}
variable "encryption_kms_key_arn" {
  type    = string
  default = null
}
variable "tags" {
  type    = map(string)
  default = {}
}
