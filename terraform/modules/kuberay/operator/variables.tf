variable "namespace" {
  type    = string
  default = "ray-system"
}
variable "install" {
  type    = bool
  default = true
}
variable "values" {
  type    = list(string)
  default = []
}
