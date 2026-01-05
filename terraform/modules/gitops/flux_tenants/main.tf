terraform {
  required_providers {
    kubernetes = {
      source = "hashicorp/kubernetes"
    }
  }
}

locals { tenant_names = var.enabled ? var.tenants : [] }

resource "kubernetes_namespace_v1" "tenant" {
  for_each = toset(local.tenant_names)
  metadata { name = "${var.namespace_prefix}${each.value}" }
}

# ServiceAccount per tenant used by Flux Kustomizations
resource "kubernetes_service_account_v1" "tenant" {
  for_each = toset(local.tenant_names)
  metadata {
    name      = "kustomize-sa"
    namespace = kubernetes_namespace_v1.tenant[each.key].metadata[0].name
  }
}

resource "kubernetes_role_v1" "tenant_edit" {
  for_each = toset(local.tenant_names)
  metadata {
    name      = "tenant-edit"
    namespace = kubernetes_namespace_v1.tenant[each.key].metadata[0].name
  }
  rule {
    api_groups = ["*"]
    resources  = ["*"]
    verbs      = ["get", "list", "watch", "create", "update", "patch", "delete"]
  }
}

resource "kubernetes_role_binding_v1" "tenant_edit" {
  for_each = toset(local.tenant_names)
  metadata {
    name      = "tenant-edit-binding"
    namespace = kubernetes_namespace_v1.tenant[each.key].metadata[0].name
  }
  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "Role"
    name      = kubernetes_role_v1.tenant_edit[each.key].metadata[0].name
  }
  subject {
    kind      = "ServiceAccount"
    name      = kubernetes_service_account_v1.tenant[each.key].metadata[0].name
    namespace = kubernetes_namespace_v1.tenant[each.key].metadata[0].name
  }
}

output "namespaces" {
  value = [for k, v in kubernetes_namespace_v1.tenant : v.metadata[0].name]
}
