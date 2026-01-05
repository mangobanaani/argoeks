terraform {
  required_providers {
    kubernetes = {
      source = "hashicorp/kubernetes"
    }
  }
}

resource "kubernetes_cluster_role_binding_v1" "admin" {
  count = var.enabled ? length(var.admin_groups) : 0
  metadata { name = "platform-admin-${count.index}" }
  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = "cluster-admin"
  }
  dynamic "subject" {
    for_each = [var.admin_groups[count.index]]
    content {
      kind      = "Group"
      api_group = "rbac.authorization.k8s.io"
      name      = subject.value
    }
  }
}

resource "kubernetes_cluster_role_binding_v1" "readonly" {
  count = var.enabled ? length(var.readonly_groups) : 0
  metadata { name = "platform-readonly-${count.index}" }
  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = "view"
  }
  dynamic "subject" {
    for_each = [var.readonly_groups[count.index]]
    content {
      kind      = "Group"
      api_group = "rbac.authorization.k8s.io"
      name      = subject.value
    }
  }
}

resource "kubernetes_role_binding_v1" "ns_readonly" {
  for_each = var.enabled ? toset(var.namespaces) : []
  metadata {
    name      = "namespace-readonly"
    namespace = each.value
  }
  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = "view"
  }
  subject {
    kind      = "Group"
    api_group = "rbac.authorization.k8s.io"
    name      = "platform:readonly"
  }
}
