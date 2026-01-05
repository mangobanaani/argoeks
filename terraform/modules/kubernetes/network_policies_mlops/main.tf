# Enhanced Network Policies for MLOps workloads
# Works with both standard K8s NetworkPolicy and Cilium NetworkPolicy

locals {
  # Namespaces that should have default-deny policies
  secured_namespaces = concat(
    var.platform_namespaces,
    var.tenant_namespaces
  )

  # DNS endpoints to allow for ML workloads
  ml_dns_allow_list = [
    "*.s3.*.amazonaws.com",
    "*.ecr.*.amazonaws.com",
    "*.sts.*.amazonaws.com",
    "*.logs.*.amazonaws.com",
    "*.sagemaker.*.amazonaws.com"
  ]
}

# Standard Kubernetes NetworkPolicies (work with any CNI)
# Default deny all ingress in secured namespaces
resource "kubernetes_network_policy_v1" "default_deny_ingress" {
  for_each = var.enabled && !var.cilium_mode ? toset(local.secured_namespaces) : []

  metadata {
    name      = "default-deny-ingress"
    namespace = each.value
  }

  spec {
    pod_selector {}
    policy_types = ["Ingress"]
  }
}

# Default deny all egress in secured namespaces
resource "kubernetes_network_policy_v1" "default_deny_egress" {
  for_each = var.enabled && !var.cilium_mode ? toset(local.secured_namespaces) : []

  metadata {
    name      = "default-deny-egress"
    namespace = each.value
  }

  spec {
    pod_selector {}
    policy_types = ["Egress"]
  }
}

# Allow DNS for all pods
resource "kubernetes_network_policy_v1" "allow_dns" {
  for_each = var.enabled && !var.cilium_mode ? toset(local.secured_namespaces) : []

  metadata {
    name      = "allow-dns"
    namespace = each.value
  }

  spec {
    pod_selector {}
    policy_types = ["Egress"]

    egress {
      to {
        namespace_selector {
          match_labels = {
            "kubernetes.io/metadata.name" = "kube-system"
          }
        }
        pod_selector {
          match_labels = {
            "k8s-app" = "kube-dns"
          }
        }
      }
      ports {
        port     = "53"
        protocol = "UDP"
      }
      ports {
        port     = "53"
        protocol = "TCP"
      }
    }
  }
}

# Cilium NetworkPolicies (L3-L7, FQDN-aware)
# Default deny with DNS allowed
resource "kubernetes_manifest" "cilium_default_deny" {
  for_each = var.enabled && var.cilium_mode ? toset(local.secured_namespaces) : []

  manifest = {
    apiVersion = "cilium.io/v2"
    kind       = "CiliumNetworkPolicy"
    metadata = {
      name      = "default-deny-with-dns"
      namespace = each.value
    }
    spec = {
      description      = "Default deny all with DNS allowed"
      endpointSelector = {}
      egress = [
        {
          toEndpoints = [
            {
              matchLabels = {
                "k8s:io.kubernetes.pod.namespace" = "kube-system"
                "k8s:k8s-app"                     = "kube-dns"
              }
            }
          ]
          toPorts = [
            { ports = [{ port = "53", protocol = "UDP" }] },
            { ports = [{ port = "53", protocol = "TCP" }] }
          ]
        }
      ]
    }
  }
}

# ML Training pods - allow S3, ECR, inter-pod communication
resource "kubernetes_manifest" "cilium_ml_training" {
  for_each = var.enabled && var.cilium_mode && var.enable_ml_policies ? toset(var.ml_training_namespaces) : []

  manifest = {
    apiVersion = "cilium.io/v2"
    kind       = "CiliumNetworkPolicy"
    metadata = {
      name      = "ml-training-egress"
      namespace = each.value
    }
    spec = {
      description = "Allow ML training pods to access S3, ECR, and communicate with each other"
      endpointSelector = {
        matchLabels = {
          workload-type = "training"
        }
      }
      egress = [
        # Allow inter-pod communication for distributed training
        {
          toEndpoints = [
            {
              matchLabels = {
                workload-type = "training"
              }
            }
          ]
        },
        # Allow S3 for datasets and checkpoints
        {
          toFQDNs = [
            for pattern in local.ml_dns_allow_list : { matchPattern = pattern }
          ]
          toPorts = [
            { ports = [{ port = "443", protocol = "TCP" }] }
          ]
        },
        # Allow Kubernetes API for kubeflow, etc.
        {
          toEntities = ["kube-apiserver"]
        }
      ]
      ingress = [
        # Allow monitoring/metrics scraping
        {
          fromEndpoints = [
            {
              matchLabels = {
                "k8s:io.kubernetes.pod.namespace" = "monitoring"
              }
            }
          ]
          toPorts = [
            { ports = [{ port = "8080", protocol = "TCP" }] }, # metrics
            { ports = [{ port = "9090", protocol = "TCP" }] }  # prometheus
          ]
        },
        # Allow inter-pod for distributed training
        {
          fromEndpoints = [
            {
              matchLabels = {
                workload-type = "training"
              }
            }
          ]
        }
      ]
    }
  }
}

# ML Inference pods - allow specific external access patterns
resource "kubernetes_manifest" "cilium_ml_inference" {
  for_each = var.enabled && var.cilium_mode && var.enable_ml_policies ? toset(var.ml_inference_namespaces) : []

  manifest = {
    apiVersion = "cilium.io/v2"
    kind       = "CiliumNetworkPolicy"
    metadata = {
      name      = "ml-inference-policy"
      namespace = each.value
    }
    spec = {
      description = "Allow ML inference pods controlled access"
      endpointSelector = {
        matchLabels = {
          workload-type = "inference"
        }
      }
      egress = [
        # Allow S3 for model artifacts
        {
          toFQDNs = [
            { matchPattern = "*.s3.*.amazonaws.com" }
          ]
          toPorts = [
            { ports = [{ port = "443", protocol = "TCP" }] }
          ]
        },
        # Allow database access (for feature stores, etc.)
        {
          toServices = var.inference_allowed_services
        }
      ]
      ingress = [
        # Allow ingress controller
        {
          fromEndpoints = [
            {
              matchLabels = {
                "k8s:io.kubernetes.pod.namespace" = "ingress-nginx"
              }
            },
            {
              matchLabels = {
                "k8s:io.kubernetes.pod.namespace" = "kube-system"
                "k8s:app.kubernetes.io/name"      = "aws-load-balancer-controller"
              }
            }
          ]
          toPorts = [
            { ports = [{ port = "8080", protocol = "TCP" }] },
            { ports = [{ port = "8000", protocol = "TCP" }] }
          ]
        },
        # Allow monitoring
        {
          fromEndpoints = [
            {
              matchLabels = {
                "k8s:io.kubernetes.pod.namespace" = "monitoring"
              }
            }
          ]
          toPorts = [
            { ports = [{ port = "9090", protocol = "TCP" }] }
          ]
        }
      ]
    }
  }
}

# Platform namespaces - restricted HTTPS egress only
resource "kubernetes_manifest" "cilium_platform_egress" {
  for_each = var.enabled && var.cilium_mode ? toset(var.platform_namespaces) : []

  manifest = {
    apiVersion = "cilium.io/v2"
    kind       = "CiliumNetworkPolicy"
    metadata = {
      name      = "platform-https-only"
      namespace = each.value
    }
    spec = {
      description = "Platform services can only egress on HTTPS + DNS"
      endpointSelector = {
        matchExpressions = [
          {
            key      = "app.kubernetes.io/part-of"
            operator = "Exists"
          }
        ]
      }
      egress = [
        {
          toPorts = [
            { ports = [{ port = "443", protocol = "TCP" }] }
          ]
        }
      ]
    }
  }
}
