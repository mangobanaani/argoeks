module "cluster_factory_primary" {
  source               = "../../modules/cluster_factory"
  providers            = { aws = aws.primary }
  region               = var.primary_region
  cluster_count        = var.cluster_count
  cluster_config       = var.cluster_config
  name_prefix          = "${var.name_prefix}-p"
  environment          = "prod"
  base_cidr            = var.base_cidr_primary
  admin_role_arns      = var.admin_role_arns
  readonly_role_arns   = var.readonly_role_arns
  terraform_admin_role_arns = var.terraform_admin_role_arns
  public_api_endpoint  = var.public_api_endpoint
  private_api_endpoint = var.private_api_endpoint
}

module "cluster_factory_secondary" {
  source               = "../../modules/cluster_factory"
  providers            = { aws = aws.secondary }
  region               = var.secondary_region
  cluster_count        = var.cluster_count
  cluster_config       = var.cluster_config
  name_prefix          = "${var.name_prefix}-s"
  environment          = "prod"
  base_cidr            = var.base_cidr_secondary
  admin_role_arns      = var.admin_role_arns
  readonly_role_arns   = var.readonly_role_arns
  terraform_admin_role_arns = var.terraform_admin_role_arns
  public_api_endpoint  = var.public_api_endpoint
  private_api_endpoint = var.private_api_endpoint
}

locals {
  all_cluster_names = concat(module.cluster_factory_primary.cluster_names, module.cluster_factory_secondary.cluster_names)
  all_vpc_ids_map   = merge(module.cluster_factory_primary.vpc_ids, module.cluster_factory_secondary.vpc_ids)
}

output "cluster_names" { value = local.all_cluster_names }

module "config" {
  source      = "../../modules/config/loader"
  config_path = var.platform_config_path
  environment = "prod"
}

module "gitops_bootstrap_primary" {
  source                            = "../../modules/gitops_bootstrap"
  install_argocd                    = var.enable_argocd
  install_flux                      = var.enable_flux
  argocd_namespace                  = "argocd"
  argocd_values                     = [file("../../../kubernetes/platform/argocd-hub/values.yaml")]
  argocd_admin_enabled              = false
  argocd_oidc_enabled               = var.enable_argocd_sso
  argocd_oidc_issuer                = var.argocd_sso_issuer
  argocd_oidc_client_id             = var.argocd_sso_client_id
  argocd_oidc_client_secret         = var.argocd_sso_client_secret
  argocd_server_service_type        = var.argocd_service_type
  argocd_server_service_annotations = var.argocd_service_annotations
  install_aws_lbc                   = true
  cluster_name                      = module.cluster_factory_primary.cluster_names[0]
  aws_lbc_role_arn                  = module.aws_lbc_irsa_primary.role_arn
  argocd_rbac_policy_csv            = <<-CSV
    g, platform:admin, role:admin
    g, platform:readonly, role:readonly
  CSV
  argocd_ingress_enabled            = true
  argocd_ingress_hosts              = [local.argocd_hostname]
  argocd_ingress_cert_arn           = try(module.argocd_cert[0].certificate_arn, "")
  argocd_ingress_wafv2_acl_arn      = try(module.argocd_waf[0].arn, "")
  install_external_dns              = true
  external_dns_domain_filters       = [var.private_domain]
  external_dns_role_arn             = lookup(module.external_dns_irsa_primary.role_arns, module.cluster_factory_primary.cluster_names[0], "")
  providers = {
    kubernetes = kubernetes.hub_primary
    helm       = helm.hub_primary
  }
}

module "gitops_bootstrap_secondary" {
  source                            = "../../modules/gitops_bootstrap"
  install_argocd                    = var.enable_argocd
  install_flux                      = var.enable_flux
  argocd_namespace                  = "argocd"
  argocd_values                     = [file("../../../kubernetes/platform/argocd-hub/values.yaml")]
  argocd_admin_enabled              = false
  argocd_oidc_enabled               = var.enable_argocd_sso
  argocd_oidc_issuer                = var.argocd_sso_issuer
  argocd_oidc_client_id             = var.argocd_sso_client_id
  argocd_oidc_client_secret         = var.argocd_sso_client_secret
  argocd_server_service_type        = var.argocd_service_type
  argocd_server_service_annotations = var.argocd_service_annotations
  install_aws_lbc                   = true
  cluster_name                      = module.cluster_factory_secondary.cluster_names[0]
  aws_lbc_role_arn                  = module.aws_lbc_irsa_secondary.role_arn
  argocd_rbac_policy_csv            = <<-CSV
    g, platform:admin, role:admin
    g, platform:readonly, role:readonly
  CSV
  argocd_ingress_enabled            = true
  argocd_ingress_hosts              = [local.argocd_hostname]
  argocd_ingress_cert_arn           = try(module.argocd_cert_secondary[0].certificate_arn, "")
  argocd_ingress_wafv2_acl_arn      = try(module.argocd_waf_secondary[0].arn, "")
  install_external_dns              = true
  external_dns_domain_filters       = [var.private_domain]
  external_dns_role_arn             = lookup(module.external_dns_irsa_secondary.role_arns, module.cluster_factory_secondary.cluster_names[0], "")
  providers = {
    kubernetes = kubernetes.hub_secondary
    helm       = helm.hub_secondary
  }
}

module "karpenter_primary" {
  source           = "../../modules/karpenter"
  providers        = { kubernetes = kubernetes.hub_primary, helm = helm.hub_primary }
  count            = var.enable_karpenter ? 1 : 0
  cluster_name     = module.cluster_factory_primary.cluster_names[0]
  cluster_endpoint = data.aws_eks_cluster.hub_primary.endpoint
  oidc_issuer_url  = data.aws_eks_cluster.hub_primary.identity[0].oidc[0].issuer
  region           = var.primary_region
}

module "karpenter_secondary" {
  source           = "../../modules/karpenter"
  providers        = { kubernetes = kubernetes.hub_secondary, helm = helm.hub_secondary }
  count            = var.enable_karpenter ? 1 : 0
  cluster_name     = module.cluster_factory_secondary.cluster_names[0]
  cluster_endpoint = data.aws_eks_cluster.hub_secondary.endpoint
  oidc_issuer_url  = data.aws_eks_cluster.hub_secondary.identity[0].oidc[0].issuer
  region           = var.secondary_region
}

module "kuberay_operator_primary" {
  source    = "../../modules/kuberay/operator"
  providers = { kubernetes = kubernetes.hub_primary, helm = helm.hub_primary }
  count     = var.enable_kuberay ? 1 : 0
}

module "kuberay_operator_secondary" {
  source    = "../../modules/kuberay/operator"
  providers = { kubernetes = kubernetes.hub_secondary, helm = helm.hub_secondary }
  count     = var.enable_kuberay ? 1 : 0
}

module "kubecost_primary" {
  source    = "../../modules/cost/kubecost"
  providers = { kubernetes = kubernetes.hub_primary, helm = helm.hub_primary }
  count     = var.enable_kubecost ? 1 : 0
}

module "kubecost_secondary" {
  source    = "../../modules/cost/kubecost"
  providers = { kubernetes = kubernetes.hub_secondary, helm = helm.hub_secondary }
  count     = var.enable_kubecost ? 1 : 0
}

module "thanos_primary" {
  source                      = "../../modules/observability/thanos_aggregator"
  enabled                     = var.enable_thanos
  environment                 = "prod"
  region                      = var.primary_region
  bucket_name                 = var.thanos_bucket_name
  service_account_annotations = module.irsa_thanos_primary.annotations
  bucket_role_arns            = [module.irsa_thanos_primary.role_arn]
  providers = {
    kubernetes = kubernetes.hub_primary
    helm       = helm.hub_primary
  }
}

module "thanos_secondary" {
  source      = "../../modules/observability/thanos_aggregator"
  enabled     = var.enable_thanos
  environment = "prod"
  region      = var.secondary_region
  bucket_name = ""
  providers = {
    kubernetes = kubernetes.hub_secondary
    helm       = helm.hub_secondary
  }
}

module "irsa_thanos_primary" {
  source          = "../../modules/iam/irsa"
  name            = "prod-thanos-irsa"
  namespace       = "monitoring"
  service_account = "thanos"
  oidc_issuer_url = data.aws_eks_cluster.hub_primary.identity[0].oidc[0].issuer
  policy_json = jsonencode({
    Version = "2012-10-17"
    Statement = [
      { Effect = "Allow", Action = ["s3:ListBucket"], Resource = ["arn:aws:s3:::${coalesce(var.thanos_bucket_name, module.thanos_primary.thanos_bucket)}"] },
      { Effect = "Allow", Action = ["s3:GetObject", "s3:PutObject", "s3:DeleteObject", "s3:AbortMultipartUpload", "s3:ListBucketMultipartUploads"], Resource = ["arn:aws:s3:::${coalesce(var.thanos_bucket_name, module.thanos_primary.thanos_bucket)}/*"] }
    ]
  })
}

module "irsa_thanos_secondary" {
  source          = "../../modules/iam/irsa"
  name            = "prod-thanos-irsa-secondary"
  namespace       = "monitoring"
  service_account = "thanos"
  oidc_issuer_url = data.aws_eks_cluster.hub_secondary.identity[0].oidc[0].issuer
  policy_json = jsonencode({
    Version = "2012-10-17"
    Statement = [
      { Effect = "Allow", Action = ["s3:ListBucket"], Resource = [module.thanos_secondary.thanos_bucket_arn] },
      { Effect = "Allow", Action = ["s3:GetObject", "s3:PutObject", "s3:DeleteObject", "s3:AbortMultipartUpload", "s3:ListBucketMultipartUploads"], Resource = ["${module.thanos_secondary.thanos_bucket_arn}/*"] }
    ]
  })
}

module "network_policies_primary" {
  source    = "../../modules/kubernetes/network_policies"
  enabled   = var.enable_network_policies
  providers = { kubernetes = kubernetes.hub_primary }
}

module "gatekeeper_primary" {
  source  = "../../modules/security/gatekeeper"
  enabled = var.enable_gatekeeper
  providers = {
    kubernetes = kubernetes.hub_primary
    helm       = helm.hub_primary
  }
}

module "flux_tenants_primary" {
  source    = "../../modules/gitops/flux_tenants"
  enabled   = var.enable_flux
  tenants   = var.tenants
  providers = { kubernetes = kubernetes.hub_primary }
}

module "pod_security_labels_primary" {
  source    = "../../modules/security/pod_security_labels"
  providers = { kubernetes = kubernetes.hub_primary }
}

module "private_dns" {
  source  = "../../modules/networking/private_dns"
  enabled = var.enable_private_dns
  domain  = var.private_domain
  vpc_ids = values(local.all_vpc_ids_map)
  region  = var.primary_region
  tags    = { environment = "prod" }
}

module "external_dns_irsa_primary" {
  source        = "../../modules/dns/external_dns_irsa"
  zone_id       = module.private_dns.zone_id
  cluster_names = module.cluster_factory_primary.cluster_names
  region        = var.primary_region
}

module "external_dns_irsa_secondary" {
  source        = "../../modules/dns/external_dns_irsa"
  providers     = { aws = aws.secondary }
  zone_id       = module.private_dns.zone_id
  cluster_names = module.cluster_factory_secondary.cluster_names
  region        = var.secondary_region
}

module "eso_irsa_primary" {
  source        = "../../modules/iam/eso_irsa"
  cluster_names = module.cluster_factory_primary.cluster_names
}

module "eso_irsa_secondary" {
  source        = "../../modules/iam/eso_irsa"
  providers     = { aws = aws.secondary }
  cluster_names = module.cluster_factory_secondary.cluster_names
}

module "aws_lbc_irsa_primary" {
  source          = "../../modules/iam/aws_lbc_irsa"
  name            = "prod-aws-lbc-irsa"
  oidc_issuer_url = data.aws_eks_cluster.hub_primary.identity[0].oidc[0].issuer
}

module "aws_lbc_irsa_secondary" {
  source          = "../../modules/iam/aws_lbc_irsa"
  providers       = { aws = aws.secondary }
  name            = "prod-aws-lbc-irsa-secondary"
  oidc_issuer_url = data.aws_eks_cluster.hub_secondary.identity[0].oidc[0].issuer
}

module "cloudwatch_observability_primary" {
  source       = "../../modules/observability/cloudwatch_observability"
  providers    = { aws = aws.primary }
  count        = var.enable_cloudwatch_observability ? 1 : 0
  cluster_name = module.cluster_factory_primary.cluster_names[0]
  role_name    = "prod-p-cloudwatch-observability"
  addon_version = var.cloudwatch_observability_addon_version
  tags         = { environment = "prod", region = var.primary_region }
}

module "cloudwatch_observability_secondary" {
  source       = "../../modules/observability/cloudwatch_observability"
  providers    = { aws = aws.secondary }
  count        = var.enable_cloudwatch_observability ? 1 : 0
  cluster_name = module.cluster_factory_secondary.cluster_names[0]
  role_name    = "prod-s-cloudwatch-observability"
  addon_version = var.cloudwatch_observability_addon_version
  tags         = { environment = "prod", region = var.secondary_region }
}

locals { argocd_hostname = var.argocd_host != "" ? var.argocd_host : "argocd.${var.private_domain}" }

module "argocd_cert_primary" {
  source                    = "../../modules/cert/acm_private_cert"
  count                     = var.acm_pca_arn != "" ? 1 : 0
  domain_name               = local.argocd_hostname
  certificate_authority_arn = var.acm_pca_arn
  tags                      = { environment = "prod", service = "argocd" }
}

module "argocd_cert_secondary" {
  source                    = "../../modules/cert/acm_private_cert"
  providers                 = { aws = aws.secondary }
  count                     = var.acm_pca_arn != "" ? 1 : 0
  domain_name               = local.argocd_hostname
  certificate_authority_arn = var.acm_pca_arn
  tags                      = { environment = "prod", service = "argocd" }
}

module "argocd_waf_primary" {
  source = "../../modules/security/waf_acl"
  count  = 1
  name   = "prod-argocd-waf"
  tags   = { environment = "prod", service = "argocd" }
}

module "argocd_waf_secondary" {
  source    = "../../modules/security/waf_acl"
  providers = { aws = aws.secondary }
  count     = 1
  name      = "prod-argocd-waf-secondary"
  tags      = { environment = "prod", service = "argocd" }
}

module "security_services" {
  source = "../../modules/security/security_services"
  count  = var.enable_security_services ? 1 : 0
  region = var.primary_region
}

module "cloudtrail" {
  source         = "../../modules/logging/cloudtrail"
  count          = var.enable_cloudtrail && var.cloudtrail_bucket_name != "" ? 1 : 0
  s3_bucket_name = var.cloudtrail_bucket_name
}

module "vpc_flow_logs" {
  source         = "../../modules/logging/vpc_flow_logs"
  count          = var.enable_vpc_flow_logs ? 1 : 0
  vpc_ids        = values(local.all_vpc_ids_map)
  retention_days = var.cw_vpc_flow_retention_days
}

module "notifications" {
  source             = "../../modules/alerts/notifications"
  name_prefix        = "prod"
  emails             = try(module.config.alerts.emails, [])
  slack_workspace_id = try(module.config.alerts.slack.workspace_id, "")
  slack_channel_id   = try(module.config.alerts.slack.channel_id, "")
}

module "budgets" {
  source        = "../../modules/alerts/budgets"
  name          = "prod-monthly"
  limit_amount  = try(module.config.budgets.amount, 10000)
  limit_unit    = try(module.config.budgets.currency, "USD")
  thresholds    = try(module.config.budgets.thresholds, [70, 85, 95, 100])
  emails        = try(module.config.alerts.emails, [])
  sns_topic_arn = module.notifications.sns_topic_arn
}

provider "aws" {
  alias  = "billing"
  region = "us-east-1"
}

module "billing_alarm" {
  source        = "../../modules/alerts/cloudwatch_billing"
  providers     = { aws = aws.billing }
  name          = "prod-billing"
  currency      = try(module.config.budgets.currency, "USD")
  threshold     = try(module.config.budgets.billing_alarm_threshold, 9000)
  sns_topic_arn = module.notifications.sns_topic_arn
}

module "alb_alarms_primary" {
  source        = "../../modules/alerts/alb_alarms"
  providers     = { aws = aws.primary }
  count         = var.enable_alb_alarms ? 1 : 0
  name_prefix   = "prod-p"
  sns_topic_arn = module.notifications.sns_topic_arn
  items         = try(module.config.monitoring.alb_alarms_primary, [])
}

module "alb_alarms_secondary" {
  source        = "../../modules/alerts/alb_alarms"
  providers     = { aws = aws.secondary }
  count         = var.enable_alb_alarms ? 1 : 0
  name_prefix   = "prod-s"
  sns_topic_arn = module.notifications.sns_topic_arn
  items         = try(module.config.monitoring.alb_alarms_secondary, [])
}

module "tg_alarms_primary" {
  source        = "../../modules/alerts/target_group_alarms"
  providers     = { aws = aws.primary }
  count         = var.enable_tg_alarms ? 1 : 0
  sns_topic_arn = module.notifications.sns_topic_arn
  items         = try(module.config.monitoring.target_group_alarms_primary, [])
}

module "tg_alarms_secondary" {
  source        = "../../modules/alerts/target_group_alarms"
  providers     = { aws = aws.secondary }
  count         = var.enable_tg_alarms ? 1 : 0
  sns_topic_arn = module.notifications.sns_topic_arn
  items         = try(module.config.monitoring.target_group_alarms_secondary, [])
}

module "s3_alarms_primary" {
  source        = "../../modules/alerts/s3_alarms"
  providers     = { aws = aws.primary }
  count         = var.enable_s3_alarms ? 1 : 0
  sns_topic_arn = module.notifications.sns_topic_arn
  items         = try(module.config.monitoring.s3_alarms_primary, [])
}

module "s3_alarms_secondary" {
  source        = "../../modules/alerts/s3_alarms"
  providers     = { aws = aws.secondary }
  count         = var.enable_s3_alarms ? 1 : 0
  sns_topic_arn = module.notifications.sns_topic_arn
  items         = try(module.config.monitoring.s3_alarms_secondary, [])
}

module "security_findings_primary" {
  source        = "../../modules/alerts/security_findings"
  providers     = { aws = aws.primary }
  count         = var.enable_security_findings ? 1 : 0
  sns_topic_arn = module.notifications.sns_topic_arn
}

module "security_findings_secondary" {
  source        = "../../modules/alerts/security_findings"
  providers     = { aws = aws.secondary }
  count         = var.enable_security_findings ? 1 : 0
  sns_topic_arn = module.notifications.sns_topic_arn
}

locals {
  rds_alarm_defaults = try(module.config.monitoring.rds_alarms, {
    period              = 60, evals = 3, cpu_high_threshold = 80,
    free_storage_low_mb = 51200, freeable_memory_low_mb = 2048,
    read_latency_sec    = 0.05, write_latency_sec = 0.05, connections_high = 1500
  })
  redis_alarm_defaults = try(module.config.monitoring.redis_alarms, {
    period = 60, evals = 3, cpu_high_threshold = 80, freeable_memory_low_mb = 2048, evictions_threshold = 1
  })
}

module "rds_alarms" {
  source        = "../../modules/alerts/rds_alarms"
  sns_topic_arn = module.notifications.sns_topic_arn
  items = concat(
    (var.enable_rds_postgres && length(module.rds_postgres) > 0) ? [{
      instance_id            = module.rds_postgres[0].db_instance_identifier
      period                 = local.rds_alarm_defaults.period
      evals                  = local.rds_alarm_defaults.evals
      cpu_high_threshold     = local.rds_alarm_defaults.cpu_high_threshold
      free_storage_low_mb    = local.rds_alarm_defaults.free_storage_low_mb
      freeable_memory_low_mb = local.rds_alarm_defaults.freeable_memory_low_mb
      read_latency_sec       = local.rds_alarm_defaults.read_latency_sec
      write_latency_sec      = local.rds_alarm_defaults.write_latency_sec
      connections_high       = local.rds_alarm_defaults.connections_high
    }] : [],
    (var.enable_aurora && !var.enable_aurora_global && length(module.aurora) > 0) ? [for id in module.aurora[0].instance_ids : {
      instance_id            = id
      period                 = local.rds_alarm_defaults.period
      evals                  = local.rds_alarm_defaults.evals
      cpu_high_threshold     = local.rds_alarm_defaults.cpu_high_threshold
      free_storage_low_mb    = local.rds_alarm_defaults.free_storage_low_mb
      freeable_memory_low_mb = local.rds_alarm_defaults.freeable_memory_low_mb
      read_latency_sec       = local.rds_alarm_defaults.read_latency_sec
      write_latency_sec      = local.rds_alarm_defaults.write_latency_sec
      connections_high       = local.rds_alarm_defaults.connections_high
    }] : [],
    (var.enable_aurora_global && length(module.aurora_global) > 0) ? concat(
      [for id in module.aurora_global[0].primary_instance_ids : {
        instance_id            = id
        period                 = local.rds_alarm_defaults.period
        evals                  = local.rds_alarm_defaults.evals
        cpu_high_threshold     = local.rds_alarm_defaults.cpu_high_threshold
        free_storage_low_mb    = local.rds_alarm_defaults.free_storage_low_mb
        freeable_memory_low_mb = local.rds_alarm_defaults.freeable_memory_low_mb
        read_latency_sec       = local.rds_alarm_defaults.read_latency_sec
        write_latency_sec      = local.rds_alarm_defaults.write_latency_sec
        connections_high       = local.rds_alarm_defaults.connections_high
      }],
      [for id in module.aurora_global[0].secondary_instance_ids : {
        instance_id            = id
        period                 = local.rds_alarm_defaults.period
        evals                  = local.rds_alarm_defaults.evals
        cpu_high_threshold     = local.rds_alarm_defaults.cpu_high_threshold
        free_storage_low_mb    = local.rds_alarm_defaults.free_storage_low_mb
        freeable_memory_low_mb = local.rds_alarm_defaults.freeable_memory_low_mb
        read_latency_sec       = local.rds_alarm_defaults.read_latency_sec
        write_latency_sec      = local.rds_alarm_defaults.write_latency_sec
        connections_high       = local.rds_alarm_defaults.connections_high
      }]
    ) : []
  )
}

module "redis_alarms_primary" {
  source        = "../../modules/alerts/redis_alarms"
  providers     = { aws = aws.primary }
  sns_topic_arn = module.notifications.sns_topic_arn
  items = var.enable_redis && length(module.redis) > 0 ? [{
    replication_group_id   = module.redis[0].replication_group_id
    period                 = local.redis_alarm_defaults.period
    evals                  = local.redis_alarm_defaults.evals
    cpu_high_threshold     = local.redis_alarm_defaults.cpu_high_threshold
    freeable_memory_low_mb = local.redis_alarm_defaults.freeable_memory_low_mb
    evictions_threshold    = local.redis_alarm_defaults.evictions_threshold
  }] : []
}

module "waf_alarms_primary" {
  source        = "../../modules/alerts/waf_alarms"
  sns_topic_arn = module.notifications.sns_topic_arn
  items         = try(module.config.monitoring.waf_alarms_primary, [{ acl_name = "prod-argocd-waf", blocked_threshold = 1000, period = 300, evals = 1 }])
}

module "waf_alarms_secondary" {
  source        = "../../modules/alerts/waf_alarms"
  providers     = { aws = aws.secondary }
  sns_topic_arn = module.notifications.sns_topic_arn
  items         = try(module.config.monitoring.waf_alarms_secondary, [{ acl_name = "prod-argocd-waf-secondary", blocked_threshold = 1000, period = 300, evals = 1 }])
}

module "lambda_functions_primary" {
  for_each        = var.enable_functions ? { for f in try(module.config.functions, []) : f.name => f } : {}
  source          = "../../modules/functions/lambda_function"
  providers       = { aws = aws.primary }
  name            = "${each.value.name}-p"
  artifact_path   = "${path.root}/../../../functions/dist/${each.value.package}.zip"
  runtime         = try(each.value.runtime, "python3.12")
  handler         = try(each.value.handler, "handler.handler")
  memory_size     = try(each.value.memory, 256)
  timeout         = try(each.value.timeout, 10)
  architectures   = try(each.value.architectures, ["x86_64"])
  environment     = try(each.value.env, {})
  create_http_api = try(each.value.http_api.enabled, false)
  http_routes     = try(each.value.http_api.routes, ["GET /"])
}

module "lambda_functions_secondary" {
  for_each        = var.enable_functions ? { for f in try(module.config.functions, []) : f.name => f } : {}
  source          = "../../modules/functions/lambda_function"
  providers       = { aws = aws.secondary }
  name            = "${each.value.name}-s"
  artifact_path   = "${path.root}/../../../functions/dist/${each.value.package}.zip"
  runtime         = try(each.value.runtime, "python3.12")
  handler         = try(each.value.handler, "handler.handler")
  memory_size     = try(each.value.memory, 256)
  timeout         = try(each.value.timeout, 10)
  architectures   = try(each.value.architectures, ["x86_64"])
  environment     = try(each.value.env, {})
  create_http_api = try(each.value.http_api.enabled, false)
  http_routes     = try(each.value.http_api.routes, ["GET /"])
}

module "rds_postgres" {
  source                = "../../modules/db/rds_postgres"
  count                 = var.enable_rds_postgres ? 1 : 0
  name                  = "prod-mlops-postgres"
  vpc_id                = module.cluster_factory_primary.vpc_ids[module.cluster_factory_primary.cluster_names[0]]
  subnet_ids            = module.cluster_factory_primary.private_subnets[module.cluster_factory_primary.cluster_names[0]]
  vpc_cidr              = "10.128.0.0/8"
  instance_class        = var.rds_instance_class
  backup_retention_days = var.rds_backup_retention
  skip_final_snapshot   = var.rds_skip_final_snapshot
}

# S3 replication for Thanos buckets (primary -> secondary)
module "thanos_replication" {
  source             = "../../modules/s3/replication"
  count              = var.enable_thanos && module.thanos_primary.thanos_bucket != null && module.thanos_secondary.thanos_bucket != null ? 1 : 0
  source_bucket      = module.thanos_primary.thanos_bucket
  destination_bucket = module.thanos_secondary.thanos_bucket
  destination_region = var.secondary_region
  kms_key_arn        = module.thanos_secondary.kms_key_arn
}

module "redis" {
  source     = "../../modules/cache/elasticache_redis"
  count      = var.enable_redis ? 1 : 0
  name       = "prod-mlops-redis"
  vpc_id     = module.cluster_factory.vpc_ids[module.cluster_factory.cluster_names[0]]
  subnet_ids = module.cluster_factory.private_subnets[module.cluster_factory.cluster_names[0]]
  vpc_cidr   = "10.128.0.0/8"
}

module "msk_primary" {
  source                 = "../../modules/data/msk"
  providers              = { aws = aws.primary }
  count                  = var.enable_msk ? 1 : 0
  name                   = "prod-msk-p"
  kafka_version          = "3.6.0"
  number_of_broker_nodes = 3
  broker_instance_type   = "kafka.m5.large"
  vpc_id                 = module.cluster_factory_primary.vpc_ids[module.cluster_factory_primary.cluster_names[0]]
  subnet_ids             = module.cluster_factory_primary.private_subnets[module.cluster_factory_primary.cluster_names[0]]
  security_group_ids     = []
}

module "msk_secondary" {
  source                 = "../../modules/data/msk"
  providers              = { aws = aws.secondary }
  count                  = var.enable_msk ? 1 : 0
  name                   = "prod-msk-s"
  kafka_version          = "3.6.0"
  number_of_broker_nodes = 3
  broker_instance_type   = "kafka.m5.large"
  vpc_id                 = module.cluster_factory_secondary.vpc_ids[module.cluster_factory_secondary.cluster_names[0]]
  subnet_ids             = module.cluster_factory_secondary.private_subnets[module.cluster_factory_secondary.cluster_names[0]]
  security_group_ids     = []
}

module "amp_primary" {
  source    = "../../modules/monitoring/amp"
  providers = { aws = aws.primary }
  count     = var.enable_amp ? 1 : 0
  alias     = "prod-amp-p"
}

module "amp_secondary" {
  source    = "../../modules/monitoring/amp"
  providers = { aws = aws.secondary }
  count     = var.enable_amp ? 1 : 0
  alias     = "prod-amp-s"
}

module "amg_primary" {
  source    = "../../modules/monitoring/amg"
  providers = { aws = aws.primary }
  count     = var.enable_amg ? 1 : 0
}

module "amg_secondary" {
  source    = "../../modules/monitoring/amg"
  providers = { aws = aws.secondary }
  count     = var.enable_amg ? 1 : 0
}

module "rbac" {
  source    = "../../modules/kubernetes/rbac"
  enabled   = true
  providers = { kubernetes = kubernetes.hub }
}
