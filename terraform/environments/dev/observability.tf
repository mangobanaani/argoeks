locals {
  thanos_bucket_target = var.thanos_bucket_name != "" ? var.thanos_bucket_name : "${local.thanos_bucket_base}-*"
}

module "irsa_thanos" {
  count           = var.enable_thanos ? 1 : 0
  source          = "../../modules/iam/irsa"
  name            = "dev-thanos-irsa"
  namespace       = "monitoring"
  service_account = "thanos"
  oidc_issuer_url = data.aws_eks_cluster.hub.identity[0].oidc[0].issuer
  policy_json = jsonencode({
    Version = "2012-10-17"
    Statement = [
      { Effect = "Allow", Action = ["s3:ListBucket"], Resource = ["arn:aws:s3:::${local.thanos_bucket_target}"] },
      { Effect = "Allow", Action = ["s3:GetObject", "s3:PutObject", "s3:DeleteObject", "s3:AbortMultipartUpload", "s3:ListBucketMultipartUploads"], Resource = ["arn:aws:s3:::${local.thanos_bucket_target}/*"] }
    ]
  })
}

module "thanos_aggregator" {
  source                      = "../../modules/observability/thanos_aggregator"
  enabled                     = var.enable_thanos
  environment                 = "dev"
  region                      = var.region
  bucket_name                 = var.thanos_bucket_name
  service_account_annotations = length(module.irsa_thanos) > 0 ? module.irsa_thanos[0].annotations : {}
  bucket_role_arns            = length(module.irsa_thanos) > 0 ? [module.irsa_thanos[0].role_arn] : []
  providers = {
    kubernetes = kubernetes.hub
    helm       = helm.hub
  }
}


module "argocd_cert" {
  source                    = "../../modules/cert/acm_private_cert"
  count                     = var.acm_pca_arn != "" ? 1 : 0
  domain_name               = local.argocd_hostname
  subject_alternative_names = []
  certificate_authority_arn = var.acm_pca_arn
  tags                      = { environment = "dev", service = "argocd" }
}

module "argocd_waf" {
  source = "../../modules/security/waf_acl"
  count  = 1
  name   = "dev-argocd-waf"
  tags   = { environment = "dev", service = "argocd" }
}

module "cloudfront" {
  source       = "../../modules/edge/cloudfront_distribution"
  count        = var.enable_cloudfront && try(local.cf.enabled, false) ? 1 : 0
  aliases      = try(local.cf.aliases, [])
  acm_cert_arn = try(local.cf.acm_cert_arn, "")
  origins      = try(local.cf.origins, [])
  behaviors    = try(local.cf.behaviors, [])
}

module "amp" {
  source = "../../modules/monitoring/amp"
  count  = var.enable_amp ? 1 : 0
  alias  = "dev-amp"
}

module "amg" {
  source = "../../modules/monitoring/amg"
  count  = var.enable_amg ? 1 : 0
}
