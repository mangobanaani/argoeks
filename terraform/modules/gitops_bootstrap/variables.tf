variable "install_argocd" {
  description = "Install Argo CD in the hub cluster"
  type        = bool
  default     = true
}

variable "install_flux" {
  description = "Install Flux in the hub cluster"
  type        = bool
  default     = false
}

variable "argocd_namespace" {

  type = string

  default = "argocd"

}

variable "flux_namespace" {

  type = string

  default = "flux-system"

}

variable "argocd_values" {
  description = "Optional extra values for Argo CD chart"
  type        = list(string)
  default     = []
}

variable "argocd_chart_version" {
  description = "Helm chart version for Argo CD"
  type        = string
  default     = "9.1.6"
}

variable "flux_values" {
  description = "Optional extra values for Flux chart"
  type        = list(string)
  default     = []
}

variable "flux_chart_version" {
  description = "Helm chart version for Flux2"
  type        = string
  default     = "2.12.1"
}

variable "argocd_admin_enabled" {
  description = "Enable Argo CD admin account"
  type        = bool
  default     = false
}

variable "argocd_oidc_enabled" {
  description = "Enable OIDC SSO for Argo CD"
  type        = bool
  default     = false
}

variable "argocd_oidc_issuer" {

  type = string

  default = ""

}
variable "argocd_oidc_client_id" {
  type    = string
  default = ""
}
variable "argocd_oidc_client_secret" {
  type    = string
  default = ""
}

variable "argocd_server_service_type" {

  type = string

  default = "LoadBalancer"

}

variable "argocd_server_service_annotations" {

  type = map(string)

  default = {}

}

variable "argocd_rbac_policy_csv" {

  type = string

  default = "g, team-admins, role:admin\ng, team-readers, role:readonly"

}

variable "install_aws_lbc" {

  type = bool

  default = true

}
variable "aws_lbc_role_arn" {
  type    = string
  default = ""
}
variable "cluster_name" {
  type    = string
  default = ""
}

variable "aws_lbc_chart_version" {
  description = "Helm chart version for AWS Load Balancer Controller"
  type        = string
  default     = "1.14.0"
}

# HTTPS ingress for Argo CD
variable "argocd_ingress_enabled" {
  type    = bool
  default = true
}
variable "argocd_ingress_hosts" {
  type    = list(string)
  default = []
}
variable "argocd_ingress_cert_arn" {
  type    = string
  default = ""
}
variable "argocd_ingress_wafv2_acl_arn" {
  type    = string
  default = ""
}
variable "alb_ssl_policy" {
  type    = string
  default = "ELBSecurityPolicy-TLS13-1-2-2021-06"
}
variable "argocd_alb_name" {
  type    = string
  default = ""
}

variable "install_external_dns" {

  type = bool

  default = true

}
variable "external_dns_zone_id" {
  type    = string
  default = ""
}
variable "external_dns_role_arn" {
  type    = string
  default = ""
}
variable "external_dns_domain_filters" {
  type    = list(string)
  default = []
}

variable "external_dns_chart_version" {
  description = "Helm chart version for ExternalDNS"
  type        = string
  default     = "1.19.0"
}
