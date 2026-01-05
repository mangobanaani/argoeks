variable "source_bucket" {
  type = string
}
variable "destination_bucket" {
  type = string
}
variable "destination_region" {
  type = string
}
variable "kms_key_arn" {
  type    = string
  default = null
}
