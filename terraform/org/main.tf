terraform {
  required_providers { aws = { source = "hashicorp/aws" } }
}

provider "aws" {
  region = var.region
}

module "org_ous" {
  source = "./modules/ou"
  count  = var.enable_org_baseline ? 1 : 0

  # Default OU layout: root contains Security + Shared Services + Workloads. Workloads fans out to training/serving/experiments/sandbox.
  ou_structure = var.ou_structure_override != null ? var.ou_structure_override : local.default_ou_structure
}

module "accounts" {
  source = "./modules/account_factory"
  count  = var.enable_org_baseline && length(var.account_definitions) > 0 ? 1 : 0

  account_definitions = var.account_definitions
  ou_id_map           = try(module.org_ous[0].ou_ids, {})
}

module "org_scp" {
  source        = "./modules/scp"
  count         = var.enable_org_baseline ? 1 : 0
  enable_strict = var.enable_scp_strict

  base_target_ids            = var.scp_base_target_ids
  strict_target_ids          = var.scp_strict_target_ids
  allowed_regions            = var.scp_allowed_regions
  automation_role_arns       = var.scp_automation_role_arns
  allowed_session_principals = var.scp_allowed_session_principals
}

module "org_security" {
  source             = "./modules/security_admin"
  count              = var.enable_org_baseline ? 1 : 0
  enable_auto_enroll = var.enable_auto_enroll
  enable_config_delegation = var.enable_config_delegation
  log_archive_account_id   = var.log_archive_account_id
  log_archive_account_email = var.log_archive_account_email
}

module "org_trail" {
  source = "./modules/cloudtrail_org"
  count  = var.enable_org_baseline ? 1 : 0

  trail_name               = "org-trail"
  bucket_name              = local.cloudtrail_bucket_name_resolved
  create_bucket            = var.cloudtrail_create_bucket
  force_destroy            = var.cloudtrail_force_destroy
  kms_key_arn              = var.cloudtrail_kms_key_arn
  replica_bucket_arn       = var.cloudtrail_replica_bucket_arn
  replica_kms_key_arn      = var.cloudtrail_replica_kms_key_arn
}
