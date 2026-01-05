module "security_services" {
  source = "../../modules/security/security_services"
  count  = var.enable_security_services ? 1 : 0
  region = var.region
}

# CloudTrail (central)
module "cloudtrail" {
  source         = "../../modules/logging/cloudtrail"
  count          = var.enable_cloudtrail && var.cloudtrail_bucket_name != "" ? 1 : 0
  s3_bucket_name = var.cloudtrail_bucket_name
}
