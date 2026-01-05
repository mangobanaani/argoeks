module "cluster_factory" {
  source             = "../../modules/cluster_factory"
  region             = var.region
  cluster_count      = var.cluster_count
  cluster_config     = var.cluster_config
  name_prefix        = var.name_prefix
  environment        = "qa"
  base_cidr          = "10.64.0.0/8"
  admin_role_arns    = var.admin_role_arns
  readonly_role_arns = var.readonly_role_arns
  terraform_admin_role_arns = var.terraform_admin_role_arns
}

output "cluster_names" {
  value = module.cluster_factory.cluster_names
}

module "config" {
  source      = "../../modules/config/loader"
  config_path = var.platform_config_path
  environment = "qa"
}

module "gitops_bootstrap" {
  source                            = "../../modules/gitops_bootstrap"
  install_argocd                    = var.enable_argocd
  install_flux                      = var.enable_flux
  argocd_namespace                  = "argocd"
  flux_namespace                    = "flux-system"
  argocd_values                     = [file("../../../kubernetes/platform/argocd-hub/values.yaml")]
  argocd_admin_enabled              = false
  argocd_oidc_enabled               = var.enable_argocd_sso
  argocd_oidc_issuer                = var.argocd_sso_issuer
  argocd_oidc_client_id             = var.argocd_sso_client_id
  argocd_oidc_client_secret         = var.argocd_sso_client_secret
  argocd_server_service_type        = var.argocd_service_type
  argocd_server_service_annotations = var.argocd_service_annotations
  install_aws_lbc                   = true
  cluster_name                      = module.cluster_factory.cluster_names[0]
  aws_lbc_role_arn                  = module.aws_lbc_irsa.role_arn
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
  external_dns_role_arn             = lookup(module.external_dns_irsa.role_arns, module.cluster_factory.cluster_names[0], "")
  providers = {
    kubernetes = kubernetes.hub
    helm       = helm.hub
  }
}

module "thanos_aggregator" {
  source                      = "../../modules/observability/thanos_aggregator"
  enabled                     = var.enable_thanos
  environment                 = "qa"
  region                      = var.region
  bucket_name                 = var.thanos_bucket_name
  service_account_annotations = module.irsa_thanos.annotations
  bucket_role_arns            = [module.irsa_thanos.role_arn]
  providers = {
    kubernetes = kubernetes.hub
    helm       = helm.hub
  }
}

module "irsa_thanos" {
  source          = "../../modules/iam/irsa"
  name            = "qa-thanos-irsa"
  namespace       = "monitoring"
  service_account = "thanos"
  oidc_issuer_url = data.aws_eks_cluster.hub.identity[0].oidc[0].issuer
  policy_json = jsonencode({
    Version = "2012-10-17"
    Statement = [
      { Effect = "Allow", Action = ["s3:ListBucket"], Resource = ["arn:aws:s3:::${coalesce(var.thanos_bucket_name, module.thanos_aggregator.thanos_bucket)}"] },
      { Effect = "Allow", Action = ["s3:GetObject", "s3:PutObject", "s3:DeleteObject", "s3:AbortMultipartUpload", "s3:ListBucketMultipartUploads"], Resource = ["arn:aws:s3:::${coalesce(var.thanos_bucket_name, module.thanos_aggregator.thanos_bucket)}/*"] }
    ]
  })
}

module "network_policies" {
  source    = "../../modules/kubernetes/network_policies"
  enabled   = var.enable_network_policies
  providers = { kubernetes = kubernetes.hub }
}

module "gatekeeper" {
  source  = "../../modules/security/gatekeeper"
  enabled = var.enable_gatekeeper
  providers = {
    kubernetes = kubernetes.hub
    helm       = helm.hub
  }
}

module "flux_tenants" {
  source    = "../../modules/gitops/flux_tenants"
  enabled   = var.enable_flux
  tenants   = var.tenants
  providers = { kubernetes = kubernetes.hub }
}

module "pod_security_labels" {
  source    = "../../modules/security/pod_security_labels"
  providers = { kubernetes = kubernetes.hub }
}

module "private_dns" {
  source  = "../../modules/networking/private_dns"
  enabled = var.enable_private_dns
  domain  = var.private_domain
  vpc_ids = values(module.cluster_factory.vpc_ids)
  region  = var.region
  tags    = { environment = "qa" }
}

module "external_dns_irsa" {
  source        = "../../modules/dns/external_dns_irsa"
  zone_id       = module.private_dns.zone_id
  cluster_names = module.cluster_factory.cluster_names
  region        = var.region
}

module "eso_irsa" {
  source        = "../../modules/iam/eso_irsa"
  cluster_names = module.cluster_factory.cluster_names
}

module "aws_lbc_irsa" {
  source          = "../../modules/iam/aws_lbc_irsa"
  name            = "qa-aws-lbc-irsa"
  oidc_issuer_url = data.aws_eks_cluster.hub.identity[0].oidc[0].issuer
}

module "cloudwatch_observability" {
  source      = "../../modules/observability/cloudwatch_observability"
  count       = var.enable_cloudwatch_observability ? 1 : 0
  cluster_name = module.cluster_factory.cluster_names[0]
  role_name    = "qa-cloudwatch-observability"
  addon_version = var.cloudwatch_observability_addon_version
  tags         = { environment = "qa" }
}

locals { argocd_hostname = var.argocd_host != "" ? var.argocd_host : "argocd.${var.private_domain}" }

module "argocd_cert" {
  source                    = "../../modules/cert/acm_private_cert"
  count                     = var.acm_pca_arn != "" ? 1 : 0
  domain_name               = local.argocd_hostname
  certificate_authority_arn = var.acm_pca_arn
  tags                      = { environment = "qa", service = "argocd" }
}

module "argocd_waf" {
  source = "../../modules/security/waf_acl"
  count  = 1
  name   = "qa-argocd-waf"
  tags   = { environment = "qa", service = "argocd" }
}

module "security_services" {
  source = "../../modules/security/security_services"
  count  = var.enable_security_services ? 1 : 0
  region = var.region
}

module "cloudtrail" {
  source         = "../../modules/logging/cloudtrail"
  count          = var.enable_cloudtrail && var.cloudtrail_bucket_name != "" ? 1 : 0
  s3_bucket_name = var.cloudtrail_bucket_name
}

module "vpc_flow_logs" {
  source         = "../../modules/logging/vpc_flow_logs"
  count          = var.enable_vpc_flow_logs ? 1 : 0
  vpc_ids        = values(module.cluster_factory.vpc_ids)
  retention_days = var.cw_vpc_flow_retention_days
}

module "notifications" {
  source             = "../../modules/alerts/notifications"
  name_prefix        = "qa"
  emails             = try(module.config.alerts.emails, [])
  slack_workspace_id = try(module.config.alerts.slack.workspace_id, "")
  slack_channel_id   = try(module.config.alerts.slack.channel_id, "")
}

module "budgets" {
  source        = "../../modules/alerts/budgets"
  name          = "qa-monthly"
  limit_amount  = try(module.config.budgets.amount, 1500)
  limit_unit    = try(module.config.budgets.currency, "USD")
  thresholds    = try(module.config.budgets.thresholds, [80, 95, 100])
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
  name          = "qa-billing"
  currency      = try(module.config.budgets.currency, "USD")
  threshold     = try(module.config.budgets.billing_alarm_threshold, 1300)
  sns_topic_arn = module.notifications.sns_topic_arn
}

module "alb_alarms" {
  source        = "../../modules/alerts/alb_alarms"
  count         = var.enable_alb_alarms ? 1 : 0
  name_prefix   = "qa"
  sns_topic_arn = module.notifications.sns_topic_arn
  items         = try(module.config.monitoring.alb_alarms, [])
}

module "tg_alarms" {
  source        = "../../modules/alerts/target_group_alarms"
  count         = var.enable_tg_alarms ? 1 : 0
  sns_topic_arn = module.notifications.sns_topic_arn
  items         = try(module.config.monitoring.target_group_alarms, [])
}

module "s3_alarms" {
  source        = "../../modules/alerts/s3_alarms"
  count         = var.enable_s3_alarms ? 1 : 0
  sns_topic_arn = module.notifications.sns_topic_arn
  items         = try(module.config.monitoring.s3_alarms, [])
}

module "security_findings" {
  source        = "../../modules/alerts/security_findings"
  count         = var.enable_security_findings ? 1 : 0
  sns_topic_arn = module.notifications.sns_topic_arn
}

locals {
  rds_alarm_defaults = try(module.config.monitoring.rds_alarms, {
    period              = 60, evals = 3, cpu_high_threshold = 80,
    free_storage_low_mb = 20480, freeable_memory_low_mb = 1024,
    read_latency_sec    = 0.08, write_latency_sec = 0.08, connections_high = 800
  })
  redis_alarm_defaults = try(module.config.monitoring.redis_alarms, {
    period = 60, evals = 3, cpu_high_threshold = 80, freeable_memory_low_mb = 1024, evictions_threshold = 1
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
    (var.enable_aurora && length(module.aurora) > 0) ? [for id in module.aurora[0].instance_ids : {
      instance_id            = id
      period                 = local.rds_alarm_defaults.period
      evals                  = local.rds_alarm_defaults.evals
      cpu_high_threshold     = local.rds_alarm_defaults.cpu_high_threshold
      free_storage_low_mb    = local.rds_alarm_defaults.free_storage_low_mb
      freeable_memory_low_mb = local.rds_alarm_defaults.freeable_memory_low_mb
      read_latency_sec       = local.rds_alarm_defaults.read_latency_sec
      write_latency_sec      = local.rds_alarm_defaults.write_latency_sec
      connections_high       = local.rds_alarm_defaults.connections_high
    }] : []
  )
}

module "redis_alarms" {
  source        = "../../modules/alerts/redis_alarms"
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

module "waf_alarms" {
  source        = "../../modules/alerts/waf_alarms"
  sns_topic_arn = module.notifications.sns_topic_arn
  items         = try(module.config.monitoring.waf_alarms, [{ acl_name = "qa-argocd-waf", blocked_threshold = 100, period = 300, evals = 1 }])
}

module "karpenter" {
  source           = "../../modules/karpenter"
  count            = var.enable_karpenter ? 1 : 0
  cluster_name     = module.cluster_factory.cluster_names[0]
  cluster_endpoint = data.aws_eks_cluster.hub.endpoint
  oidc_issuer_url  = data.aws_eks_cluster.hub.identity[0].oidc[0].issuer
  region           = var.region
  providers = {
    kubernetes = kubernetes.hub
    helm       = helm.hub
  }
}

module "kuberay_operator" {
  source = "../../modules/kuberay/operator"
  count  = var.enable_kuberay ? 1 : 0
  providers = {
    kubernetes = kubernetes.hub
    helm       = helm.hub
  }
}

module "kubecost" {
  source = "../../modules/cost/kubecost"
  count  = var.enable_kubecost ? 1 : 0
  providers = {
    kubernetes = kubernetes.hub
    helm       = helm.hub
  }
}

module "lambda_functions" {
  for_each        = var.enable_functions ? { for f in try(module.config.functions, []) : f.name => f } : {}
  source          = "../../modules/functions/lambda_function"
  name            = each.value.name
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
  name                  = "qa-mlops-postgres"
  vpc_id                = module.cluster_factory.vpc_ids[module.cluster_factory.cluster_names[0]]
  subnet_ids            = module.cluster_factory.private_subnets[module.cluster_factory.cluster_names[0]]
  vpc_cidr              = "10.64.0.0/8"
  instance_class        = var.rds_instance_class
  backup_retention_days = var.rds_backup_retention
  skip_final_snapshot   = var.rds_skip_final_snapshot
}

module "redis" {
  source     = "../../modules/cache/elasticache_redis"
  count      = var.enable_redis ? 1 : 0
  name       = "qa-mlops-redis"
  vpc_id     = module.cluster_factory.vpc_ids[module.cluster_factory.cluster_names[0]]
  subnet_ids = module.cluster_factory.private_subnets[module.cluster_factory.cluster_names[0]]
  vpc_cidr   = "10.64.0.0/8"
}

module "msk" {
  source                 = "../../modules/data/msk"
  count                  = var.enable_msk ? 1 : 0
  name                   = "qa-msk"
  kafka_version          = "3.6.0"
  number_of_broker_nodes = 3
  broker_instance_type   = "kafka.m5.large"
  vpc_id                 = module.cluster_factory.vpc_ids[module.cluster_factory.cluster_names[0]]
  subnet_ids             = module.cluster_factory.private_subnets[module.cluster_factory.cluster_names[0]]
  security_group_ids     = []
}

module "amp" {
  source = "../../modules/monitoring/amp"
  count  = var.enable_amp ? 1 : 0
  alias  = "qa-amp"
}

module "amg" {
  source = "../../modules/monitoring/amg"
  count  = var.enable_amg ? 1 : 0
}
module "rbac" {
  source    = "../../modules/kubernetes/rbac"
  enabled   = true
  providers = { kubernetes = kubernetes.hub }
}
