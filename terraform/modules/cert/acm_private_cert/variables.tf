variable "domain_name" {
  type = string
}
variable "subject_alternative_names" {
  type    = list(string)
  default = []
}
variable "certificate_authority_arn" {
  type = string
}
variable "tags" {
  type    = map(string)
  default = {}
}
