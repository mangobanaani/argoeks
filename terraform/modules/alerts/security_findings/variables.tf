variable "sns_topic_arn" {
  type = string
}
variable "enable_security_hub" {
  type    = bool
  default = true
}
variable "enable_guardduty" {
  type    = bool
  default = true
}
variable "security_hub_severities" {
  type    = list(string)
  default = ["HIGH", "CRITICAL"]
}
variable "guardduty_min_severity" {
  type    = number
  default = 7
}
