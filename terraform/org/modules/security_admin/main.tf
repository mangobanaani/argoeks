# Security Hub / GuardDuty admin (management account)
data "aws_caller_identity" "me" {}

locals {
  invite_log_archive = var.log_archive_account_id != "" && var.log_archive_account_email != ""
}

resource "aws_securityhub_account" "admin" {}

resource "aws_guardduty_detector" "admin" { enable = true }

resource "aws_securityhub_organization_admin_account" "this" {
  count            = var.enable_auto_enroll ? 1 : 0
  admin_account_id = data.aws_caller_identity.me.account_id
}

resource "aws_guardduty_organization_admin_account" "gadmin" {
  count            = var.enable_auto_enroll ? 1 : 0
  admin_account_id = data.aws_caller_identity.me.account_id
}

resource "aws_organizations_delegated_administrator" "securityhub" {
  count             = var.enable_auto_enroll ? 1 : 0
  account_id        = data.aws_caller_identity.me.account_id
  service_principal = "securityhub.amazonaws.com"
  depends_on        = [aws_securityhub_organization_admin_account.this]
}

resource "aws_organizations_delegated_administrator" "guardduty" {
  count             = var.enable_auto_enroll ? 1 : 0
  account_id        = data.aws_caller_identity.me.account_id
  service_principal = "guardduty.amazonaws.com"
  depends_on        = [aws_guardduty_organization_admin_account.gadmin]
}

resource "aws_securityhub_organization_configuration" "auto" {
  count       = var.enable_auto_enroll ? 1 : 0
  auto_enable = true
  depends_on  = [aws_securityhub_organization_admin_account.this]
}

resource "aws_guardduty_organization_configuration" "gauto" {
  count                            = var.enable_auto_enroll ? 1 : 0
  auto_enable_organization_members = "ALL"
  detector_id                      = aws_guardduty_detector.admin.id
  depends_on                       = [aws_guardduty_organization_admin_account.gadmin]
}

resource "aws_organizations_delegated_administrator" "config" {
  count             = var.enable_config_delegation ? 1 : 0
  account_id        = data.aws_caller_identity.me.account_id
  service_principal = "config.amazonaws.com"
}

resource "aws_securityhub_member" "log_archive" {
  count      = local.invite_log_archive ? 1 : 0
  account_id = var.log_archive_account_id
  email      = var.log_archive_account_email
  invite     = true
  depends_on = [aws_securityhub_account.admin]
}

resource "aws_guardduty_member" "log_archive" {
  count        = local.invite_log_archive ? 1 : 0
  account_id   = var.log_archive_account_id
  detector_id  = aws_guardduty_detector.admin.id
  email        = var.log_archive_account_email
  invite       = true
  disable_email_notification = false
  depends_on   = [aws_guardduty_detector.admin]
}
