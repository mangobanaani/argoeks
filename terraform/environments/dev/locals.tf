data "aws_eks_cluster" "hub" {
  name       = module.cluster_factory.cluster_names[0]
  depends_on = [module.cluster_factory]
}

data "aws_eks_cluster_auth" "hub" {
  name       = module.cluster_factory.cluster_names[0]
  depends_on = [module.cluster_factory]
}

data "aws_caller_identity" "current" {}

data "aws_region" "current" {}
locals {
  environment = "dev"
  hub_cluster = module.cluster_factory.cluster_names[0]
  hub_vpc_id  = module.cluster_factory.vpc_ids[local.hub_cluster]
  hub_subnets = module.cluster_factory.private_subnets[local.hub_cluster]

  # Argo CD configuration
  argocd_hostname = var.argocd_host != "" ? var.argocd_host : "argocd.${var.private_domain}"

  # Thanos bucket name (for IRSA policy - avoids circular dependency)
  thanos_bucket_base = "thanos-dev-${var.region}"

  # CloudFront configuration from config file
  cloudfront_config = try(module.config.edge.dev.cloudfront, try(module.config.edge.cloudfront, {}))

  # Common tags
  common_tags = {
    environment = local.environment
    managed_by  = "terraform"
    project     = "argoeks"
  }

  # Alarm defaults from config with fallbacks
  rds_alarm_defaults = try(module.config.monitoring.rds_alarms, {
    period                 = 60
    evals                  = 3
    cpu_high_threshold     = 80
    free_storage_low_mb    = 10240
    freeable_memory_low_mb = 512
    read_latency_sec       = 0.1
    write_latency_sec      = 0.1
    connections_high       = 500
  })

  redis_alarm_defaults = try(module.config.monitoring.redis_alarms, {
    period                 = 60
    evals                  = 3
    cpu_high_threshold     = 80
    freeable_memory_low_mb = 512
    evictions_threshold    = 1
  })

  # OIDC issuer for IRSA
  oidc_issuer_url = data.aws_eks_cluster.hub.identity[0].oidc[0].issuer

  # VPC CIDR for security group rules
  hub_vpc_cidr = "10.0.0.0/8"
}

locals {
  cf = try(module.config.edge.dev.cloudfront, try(module.config.edge.cloudfront, {}))
}
