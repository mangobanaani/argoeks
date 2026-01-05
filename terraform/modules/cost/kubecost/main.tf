resource "kubernetes_namespace_v1" "ns" {
  count = var.install ? 1 : 0
  metadata { name = var.namespace }
}

resource "helm_release" "kubecost" {
  count      = var.install ? 1 : 0
  name       = "kubecost"
  namespace  = var.namespace
  repository = "https://kubecost.github.io/cost-analyzer/"
  chart      = "cost-analyzer"
  version    = var.kubecost_chart_version
  wait       = true
  timeout    = 600
  values     = var.values
  depends_on = [kubernetes_namespace_v1.ns]
}
terraform {
  required_providers {
    kubernetes = {
      source = "hashicorp/kubernetes"
    }
    helm = {
      source = "hashicorp/helm"
    }
  }
}
