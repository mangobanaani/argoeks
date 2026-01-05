variable "zone_id" {
  type = string
}
variable "cluster_names" {
  type = list(string)
}
variable "cluster_oidc_issuer_urls" {
  description = "Map of cluster names to their OIDC issuer URLs"
  type        = map(string)
}
variable "cluster_oidc_providers" {
  description = "Map of cluster names to their OIDC provider hostpaths (without https://). If empty, values are derived from the issuer URLs."
  type        = map(string)
  default     = {}
}
variable "region" {
  type = string
}
variable "policy_prefix" {
  type    = string
  default = "external-dns"
}
