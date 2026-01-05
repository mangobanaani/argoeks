# Cluster outputs
output "cluster_names" {
  description = "List of EKS cluster names"
  value       = module.cluster_factory.cluster_names
}

output "hub_cluster_name" {
  description = "Name of the hub (first) cluster"
  value       = local.hub_cluster
}

output "cluster_endpoints" {
  description = "Map of cluster names to their API endpoints"
  value       = module.cluster_factory.cluster_endpoints
  sensitive   = true
}

# Network outputs
output "vpc_ids" {
  description = "Map of cluster names to VPC IDs"
  value       = module.cluster_factory.vpc_ids
}

output "private_dns_zone_id" {
  description = "Route53 private hosted zone ID"
  value       = var.enable_private_dns ? module.private_dns.zone_id : null
}

output "private_domain" {
  description = "Private DNS domain"
  value       = var.private_domain
}

# IRSA role outputs
output "thanos_role_arn" {
  description = "IAM role ARN for Thanos S3 access"
  value       = var.enable_thanos ? module.irsa_thanos[0].role_arn : null
}

output "external_dns_role_arns" {
  description = "Map of cluster names to ExternalDNS IAM role ARNs"
  value       = module.external_dns_irsa.role_arns
}

output "eso_role_arns" {
  description = "Map of cluster names to External Secrets Operator IAM role ARNs"
  value       = module.eso_irsa.role_arns
}

output "aws_lbc_role_arn" {
  description = "IAM role ARN for AWS Load Balancer Controller"
  value       = module.aws_lbc_irsa.role_arn
}

# Observability outputs
output "thanos_bucket" {
  description = "S3 bucket name for Thanos storage"
  value       = var.enable_thanos ? module.thanos_aggregator.thanos_bucket : null
}

output "amp_workspace_id" {
  description = "Amazon Managed Prometheus workspace ID"
  value       = var.enable_amp ? module.amp[0].workspace_id : null
}

output "amg_workspace_id" {
  description = "Amazon Managed Grafana workspace ID"
  value       = var.enable_amg ? module.amg[0].workspace_id : null
}

# Database outputs
output "rds_endpoint" {
  description = "RDS Postgres endpoint"
  value       = var.enable_rds_postgres ? module.rds_postgres[0].endpoint : null
  sensitive   = true
}

output "redis_endpoint" {
  description = "ElastiCache Redis primary endpoint"
  value       = var.enable_redis ? module.redis[0].primary_endpoint : null
  sensitive   = true
}

output "aurora_endpoint" {
  description = "Aurora cluster endpoint"
  value       = var.enable_aurora ? module.aurora[0].endpoint : null
  sensitive   = true
}

# Security outputs
output "argocd_waf_arn" {
  description = "WAF ACL ARN for Argo CD"
  value       = length(module.argocd_waf) > 0 ? module.argocd_waf[0].arn : null
}

output "argocd_url" {
  description = "Argo CD URL"
  value       = var.acm_pca_arn != "" ? "https://${local.argocd_hostname}" : null
}

# Alert outputs
output "sns_topic_arn" {
  description = "SNS topic ARN for alerts"
  value       = module.notifications.sns_topic_arn
}
