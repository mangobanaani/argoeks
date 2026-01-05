variable "name" {
  type    = string
  default = "billing-estimated-charges"
}
variable "currency" {
  type    = string
  default = "USD"
}
variable "threshold" {
  type = number
}
variable "sns_topic_arn" {
  type = string
}
