variable "namespaces" {
  type    = list(string)
  default = ["argocd", "flux-system", "monitoring", "external-secrets", "kube-system", "default"]
}
