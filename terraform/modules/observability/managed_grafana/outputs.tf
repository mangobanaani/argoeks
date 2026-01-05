output "workspace_id" {
  description = "Grafana workspace ID"
  value       = var.enabled ? aws_grafana_workspace.this[0].id : null
}

output "workspace_endpoint" {
  description = "Grafana workspace endpoint URL"
  value       = var.enabled ? aws_grafana_workspace.this[0].endpoint : null
}

output "workspace_arn" {
  description = "Grafana workspace ARN"
  value       = var.enabled ? aws_grafana_workspace.this[0].arn : null
}

output "iam_role_arn" {
  description = "IAM role ARN for Grafana"
  value       = var.enabled && var.create_iam_role ? aws_iam_role.grafana[0].arn : null
}

output "api_key_secret_arn" {
  description = "Secrets Manager ARN containing Grafana API key"
  value       = var.enabled && var.create_api_key ? aws_secretsmanager_secret.grafana_api_key[0].arn : null
  sensitive   = true
}
