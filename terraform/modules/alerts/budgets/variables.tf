variable "name" {
  type = string
}
variable "limit_amount" {
  type = number
}
variable "limit_unit" {
  type    = string
  default = "USD"
}
variable "thresholds" {
  type    = list(number)
  default = [80, 95, 100]
}
variable "emails" {
  type    = list(string)
  default = []
}
variable "sns_topic_arn" {
  type    = string
  default = ""
}
