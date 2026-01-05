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

resource "kubernetes_namespace_v1" "ns" {
  count = var.install ? 1 : 0
  metadata { name = var.namespace }
}

resource "helm_release" "kuberay" {
  count      = var.install ? 1 : 0
  name       = "kuberay-operator"
  namespace  = var.namespace
  repository = "https://ray-project.github.io/kuberay-helm/"
  chart      = "kuberay-operator"
  wait       = true
  timeout    = 600
  values     = var.values
  depends_on = [kubernetes_namespace_v1.ns]
}
