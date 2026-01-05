terraform {
  required_providers {
    kubernetes = {
      source = "hashicorp/kubernetes"
    }
  }
}

locals {
  dns_selector = {
    namespace_selector = { match_labels = { "kubernetes.io/metadata.name" = "kube-system" } }
    pod_selector       = { match_labels = { "k8s-app" = "kube-dns" } }
  }
}

resource "kubernetes_network_policy_v1" "default_deny" {
  for_each = var.enabled ? toset(var.namespaces) : []
  metadata {
    name      = "default-deny-all"
    namespace = each.value
  }
  spec {
    pod_selector {}
    policy_types = ["Ingress", "Egress"]
  }
}

resource "kubernetes_network_policy_v1" "allow_dns_egress" {
  for_each = var.enabled ? toset(var.namespaces) : []
  metadata {
    name      = "allow-dns-egress"
    namespace = each.value
  }
  spec {
    pod_selector {}
    policy_types = ["Egress"]
    egress {
      to {
        namespace_selector {
          match_labels = try(local.dns_selector.namespace_selector.match_labels, {})
        }
        pod_selector {
          match_labels = try(local.dns_selector.pod_selector.match_labels, { "k8s-app" = "kube-dns" })
        }
      }
      ports {
        port     = 53
        protocol = "UDP"
      }
      ports {
        port     = 53
        protocol = "TCP"
      }
    }
  }
}

resource "kubernetes_network_policy_v1" "allow_same_ns_ingress" {
  for_each = var.enabled ? toset(var.namespaces) : []
  metadata {
    name      = "allow-same-namespace-ingress"
    namespace = each.value
  }
  spec {
    pod_selector {}
    policy_types = ["Ingress"]
    ingress {
      from {
        pod_selector {}
      }
    }
  }
}

# Allow external access to Argo CD server when enabled
resource "kubernetes_network_policy_v1" "argocd_server_from_any" {
  count = var.enabled && var.allow_argocd_server_ingress ? 1 : 0
  metadata {
    name      = "argocd-server-allow-external"
    namespace = "argocd"
  }
  spec {
    pod_selector {
      match_labels = { "app.kubernetes.io/name" = "argocd-server" }
    }
    policy_types = ["Ingress"]
    ingress {
      from {

        ip_block {

          cidr = "0.0.0.0/0"

        }

      }
      ports {
        port     = 80
        protocol = "TCP"
      }
      ports {
        port     = 443
        protocol = "TCP"
      }
    }
  }
}

## For cluster-wide default deny, pass all namespaces via `namespaces` from env.

resource "kubernetes_network_policy_v1" "allow_https_egress" {
  for_each = var.enabled && var.restrict_egress_to_https ? toset(var.namespaces) : []
  metadata {
    name      = "allow-https-egress"
    namespace = each.value
  }
  spec {
    pod_selector {}
    policy_types = ["Egress"]
    egress {
      to {
        ip_block {
          cidr = "0.0.0.0/0"
        }
      }
      ports {
        port     = 443
        protocol = "TCP"
      }
    }
  }
}
