# Prometheus Operator CRDs
# Required before installing components that create ServiceMonitor resources (Cilium, KEDA, etc.)
resource "helm_release" "prometheus_operator_crds" {
  provider = helm.hub

  name             = "prometheus-operator-crds"
  repository       = "https://prometheus-community.github.io/helm-charts"
  chart            = "prometheus-operator-crds"
  version          = "17.0.2"
  namespace        = "monitoring"
  create_namespace = true

  # CRDs only - no actual workloads
  timeout = 300
}
