variable "name" {
  type    = string
  default = "org-trail"
}
variable "s3_bucket_name" {
  type = string
}
variable "kms_key_alias" {
  type    = string
  default = "alias/cloudtrail-logs"
}
variable "log_all_regions" {
  type    = bool
  default = true
}
variable "enable_log_file_validation" {
  type    = bool
  default = true
}
variable "cloudwatch_logs_group_name" {
  type    = string
  default = "/aws/cloudtrail/central"
}
variable "cloudwatch_logs_retention_days" {
  type    = number
  default = 400
}
