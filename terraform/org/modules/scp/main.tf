# Organization-level guardrails (SCPs)
data "aws_organizations_organization" "org" {}

locals {
  root_id       = data.aws_organizations_organization.org.roots[0].id
  base_targets  = distinct(concat([local.root_id], var.base_target_ids))
  strict_targets = distinct(
    length(var.strict_target_ids) > 0 ? var.strict_target_ids : local.base_targets
  )
}

resource "aws_organizations_policy" "deny_s3_public" {
  name        = "DenyS3Public"
  description = "Deny public S3 ACLs"
  type        = "SERVICE_CONTROL_POLICY"
  content     = file("${path.module}/policies/deny_public_s3.json")
}

resource "aws_organizations_policy_attachment" "deny_s3_public" {
  for_each  = toset(local.base_targets)
  policy_id = aws_organizations_policy.deny_s3_public.id
  target_id = each.value
}

resource "aws_organizations_policy" "require_tls" {
  name        = "RequireTLSSecureTransport"
  description = "Require TLS 1.2+ and HTTPS for AWS APIs"
  type        = "SERVICE_CONTROL_POLICY"
  content     = file("${path.module}/policies/require_tls.json")
}

resource "aws_organizations_policy_attachment" "require_tls" {
  for_each  = toset(local.base_targets)
  policy_id = aws_organizations_policy.require_tls.id
  target_id = each.value
}

# Strict set (optional and targeted)
resource "aws_organizations_policy" "deny_unsupported_regions" {
  count       = var.enable_strict ? 1 : 0
  name        = "DenyUnsupportedRegions"
  description = "Deny non-approved regions"
  type        = "SERVICE_CONTROL_POLICY"
  content     = templatefile("${path.module}/policies/deny_unsupported_regions.json.tmpl", {
    allowed_regions = jsonencode(var.allowed_regions)
  })
}

resource "aws_organizations_policy_attachment" "deny_unsupported_regions" {
  for_each  = var.enable_strict ? toset(local.strict_targets) : toset([])
  policy_id = aws_organizations_policy.deny_unsupported_regions[0].id
  target_id = each.value
}

resource "aws_organizations_policy" "deny_root" {
  count       = var.enable_strict ? 1 : 0
  name        = "DenyRootUser"
  description = "Deny root user actions"
  type        = "SERVICE_CONTROL_POLICY"
  content     = file("${path.module}/policies/deny_root.json")
}

resource "aws_organizations_policy_attachment" "deny_root" {
  for_each  = var.enable_strict ? toset(local.strict_targets) : toset([])
  policy_id = aws_organizations_policy.deny_root[0].id
  target_id = each.value
}

resource "aws_organizations_policy" "require_encryption" {
  count       = var.enable_strict ? 1 : 0
  name        = "RequireEncryption"
  description = "Require encryption at rest for core services"
  type        = "SERVICE_CONTROL_POLICY"
  content     = file("${path.module}/policies/require_encryption.json")
}

resource "aws_organizations_policy_attachment" "require_encryption" {
  for_each  = var.enable_strict ? toset(local.strict_targets) : toset([])
  policy_id = aws_organizations_policy.require_encryption[0].id
  target_id = each.value
}

resource "aws_organizations_policy" "deny_remote_access" {
  count       = length(var.allowed_session_principals) > 0 ? 1 : 0
  name        = "DenyRemoteSessions"
  description = "Deny SSM Session/Instance Connect unless using approved principals"
  type        = "SERVICE_CONTROL_POLICY"
  content     = templatefile("${path.module}/policies/deny_remote_access.json.tmpl", {
    allowed_principals = jsonencode(var.allowed_session_principals)
  })
}

resource "aws_organizations_policy_attachment" "deny_remote_access" {
  for_each  = length(var.allowed_session_principals) > 0 ? toset(local.base_targets) : toset([])
  policy_id = aws_organizations_policy.deny_remote_access[0].id
  target_id = each.value
}

resource "aws_organizations_policy" "deny_access_keys" {
  count       = length(var.automation_role_arns) > 0 ? 1 : 0
  name        = "DenyManualAccessKeys"
  description = "Deny IAM access key operations unless performed by automation roles"
  type        = "SERVICE_CONTROL_POLICY"
  content     = templatefile("${path.module}/policies/deny_access_keys.json.tmpl", {
    allowed_principals = jsonencode(var.automation_role_arns)
  })
}

resource "aws_organizations_policy_attachment" "deny_access_keys" {
  for_each  = length(var.automation_role_arns) > 0 ? toset(local.base_targets) : toset([])
  policy_id = aws_organizations_policy.deny_access_keys[0].id
  target_id = each.value
}
