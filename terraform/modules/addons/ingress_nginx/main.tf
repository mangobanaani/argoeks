resource "kubernetes_namespace_v1" "ns" {
  count = var.install ? 1 : 0
  metadata { name = var.namespace }
}

resource "helm_release" "ingress_nginx" {
  count      = var.install ? 1 : 0
  name       = "ingress-nginx"
  namespace  = var.namespace
  repository = "https://kubernetes.github.io/ingress-nginx"
  chart      = "ingress-nginx"
  version    = var.chart_version
  wait       = true
  timeout    = 600
  values     = var.values
  depends_on = [kubernetes_namespace_v1.ns]
}

