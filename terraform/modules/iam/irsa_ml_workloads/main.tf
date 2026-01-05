terraform {
  required_providers {
    kubernetes = {
      source = "hashicorp/kubernetes"
    }
  }
}

# Composite IRSA module for common ML workload patterns
# Reduces repetition when creating multiple similar IRSA roles

locals {
  # Flatten workloads to create individual roles
  workloads = { for w in var.workloads : w.name => w }
}

module "irsa_s3" {
  for_each = {
    for k, w in local.workloads : k => w
    if try(w.s3_access, null) != null
  }

  source          = "../irsa_s3"
  name            = "${var.environment}-${each.key}-irsa"
  namespace       = each.value.namespace
  service_account = each.value.service_account
  oidc_issuer_url = var.oidc_issuer_url
  bucket_arns     = each.value.s3_access.bucket_arns
  kms_key_arns    = try(each.value.s3_access.kms_key_arns, [])
  read_only       = try(each.value.s3_access.read_only, false)
  tags            = merge(var.tags, { workload = each.key })
}

module "irsa_dynamodb" {
  for_each = {
    for k, w in local.workloads : k => w
    if try(w.dynamodb_access, null) != null
  }

  source          = "../irsa_dynamodb"
  name            = "${var.environment}-${each.key}-irsa"
  namespace       = each.value.namespace
  service_account = each.value.service_account
  oidc_issuer_url = var.oidc_issuer_url
  table_arns      = each.value.dynamodb_access.table_arns
  read_only       = try(each.value.dynamodb_access.read_only, false)
  tags            = merge(var.tags, { workload = each.key })
}

module "irsa_rds" {
  for_each = {
    for k, w in local.workloads : k => w
    if try(w.rds_access, null) != null
  }

  source          = "../irsa_rds_connect"
  name            = "${var.environment}-${each.key}-rds-connect"
  namespace       = each.value.namespace
  service_account = each.value.service_account
  oidc_issuer_url = var.oidc_issuer_url
  rds_resource_id = each.value.rds_access.resource_id
  db_username     = each.value.rds_access.username
  tags            = merge(var.tags, { workload = each.key })
}

# Create namespaces if requested
resource "kubernetes_namespace_v1" "workload" {
  for_each = {
    for k, w in local.workloads : k => w
    if try(w.create_namespace, false)
  }

  metadata {
    name = each.value.namespace
    labels = merge(
      {
        name     = each.value.namespace
        workload = each.key
      },
      try(each.value.namespace_labels, {})
    )
  }
}

# Create service accounts with IRSA annotations
resource "kubernetes_service_account_v1" "workload" {
  for_each = {
    for k, w in local.workloads : k => w
    if try(w.create_service_account, false)
  }

  metadata {
    name      = each.value.service_account
    namespace = each.value.namespace
    annotations = merge(
      try(module.irsa_s3[each.key].annotations, {}),
      try(module.irsa_dynamodb[each.key].annotations, {}),
      try(module.irsa_rds[each.key].annotations, {})
    )
  }

  depends_on = [kubernetes_namespace_v1.workload]
}
