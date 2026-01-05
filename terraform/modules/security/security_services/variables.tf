variable "enable_security_hub" {
  type    = bool
  default = true
}
variable "enable_guardduty" {
  type    = bool
  default = true
}
variable "enable_inspector" {
  type    = bool
  default = true
}
variable "enable_macie" {
  type    = bool
  default = false
}
variable "standards" {
  type    = list(string)
  default = ["aws-foundational", "cis-1.4", "pci-dss"]
}
variable "region" {
  type = string
}

variable "tags" {

  type = map(string)

  default = {}

}
