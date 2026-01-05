variable "cluster_name" {
  type = string
}
variable "cluster_endpoint" {
  type = string
}
variable "oidc_issuer_url" {
  type = string
}
variable "region" {
  type = string
}

variable "namespace" {

  type = string

  default = "karpenter"

}
variable "install" {
  type    = bool
  default = true
}

variable "controller_policy_json" {
  description = "Override IAM policy JSON for the Karpenter controller role (leave blank to use the bundled default)"
  type        = string
  default     = ""
}

variable "karpenter_chart_version" {
  description = "Helm chart version for Karpenter"
  type        = string
  default     = "1.1.1"
}

variable "node_role_name" {

  type = string

  default = null

}
variable "tags" {
  type    = map(string)
  default = {}
}

variable "default_nodepool_enabled" {

  type = bool

  default = true

}
variable "default_nodepool_name" {
  type    = string
  default = "default"
}
variable "default_capacity_type" {
  type    = list(string)
  default = ["spot", "on-demand"]
}
variable "default_instance_arch" {
  type    = list(string)
  default = ["amd64", "arm64"]
}
variable "default_taints" {
  type = list(object({ key = string, value = optional(string), effect = string
  }))
  default = []
}
