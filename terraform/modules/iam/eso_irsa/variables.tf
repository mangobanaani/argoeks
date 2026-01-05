variable "cluster_names" {
  type = list(string)
}
variable "cluster_oidc_issuer_urls" {
  description = "Map of cluster names to their OIDC issuer URLs"
  type        = map(string)
}
variable "cluster_oidc_providers" {
  description = "Map of cluster names to their OIDC provider hostpaths (without https://). If empty, values are derived from issuer URLs."
  type        = map(string)
  default     = {}
}
variable "secret_arns" {
  type    = list(string)
  default = []
}
variable "secret_name_prefix" {
  type    = string
  default = "mlops/"
}
