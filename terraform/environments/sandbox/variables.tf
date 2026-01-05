variable "region" {
  type    = string
  default = "us-east-1"
}

variable "aws_profile" {

  type = string

  default = null

}

variable "cluster_count" {

  type = number

  default = 1

}

variable "cluster_config" {
  description = "Sandbox defaults (tiny, cheap)"
  type = object({
    type         = string
    size         = string
    tenancy      = string
    compliance   = string
    auto_upgrade = bool
    version      = optional(string, "1.30")
  })
  default = {
    type         = "mlops"
    size         = "small"
    tenancy      = "sandbox"
    compliance   = "none"
    auto_upgrade = true
  }
}

variable "name_prefix" {

  type = string

  default = "sbx-mlops"

}

variable "enable_argocd" {

  type = bool

  default = false

}

variable "enable_flux" {

  type = bool

  default = false

}

variable "enable_thanos" {

  type = bool

  default = false

}

variable "enable_gatekeeper" {

  type = bool

  default = false

}

variable "enable_network_policies" {

  type = bool

  default = true

}

variable "enable_private_dns" {

  type = bool

  default = true

}

