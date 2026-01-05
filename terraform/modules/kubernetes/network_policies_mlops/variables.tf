variable "enabled" {
  description = "Enable network policies"
  type        = bool
  default     = true
}

variable "cilium_mode" {
  description = "Use Cilium NetworkPolicy (L3-L7) instead of standard K8s NetworkPolicy"
  type        = bool
  default     = false
}

variable "platform_namespaces" {
  description = "List of platform namespaces to secure (argocd, monitoring, etc.)"
  type        = list(string)
  default = [
    "argocd",
    "monitoring",
    "flux-system",
    "kube-system",
    "external-secrets"
  ]
}

variable "tenant_namespaces" {
  description = "List of tenant namespaces to secure"
  type        = list(string)
  default     = []
}

variable "enable_ml_policies" {
  description = "Enable ML-specific network policies (training, inference)"
  type        = bool
  default     = true
}

variable "ml_training_namespaces" {
  description = "Namespaces where ML training workloads run"
  type        = list(string)
  default = [
    "kubeflow",
    "training",
    "mlops"
  ]
}

variable "ml_inference_namespaces" {
  description = "Namespaces where ML inference workloads run"
  type        = list(string)
  default = [
    "inference",
    "serving",
    "mlops"
  ]
}

variable "inference_allowed_services" {
  description = "Services that inference pods can access (for Cilium policies)"
  type = list(object({
    k8sService = object({
      serviceName = string
      namespace   = string
    })
  }))
  default = [
    {
      k8sService = {
        serviceName = "postgres"
        namespace   = "database"
      }
    },
    {
      k8sService = {
        serviceName = "redis"
        namespace   = "cache"
      }
    }
  ]
}
