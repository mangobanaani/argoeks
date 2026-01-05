output "role_arn" {
  value       = var.enabled ? aws_iam_role.this[0].arn : null
  description = "IAM role ARN used by the CloudWatch Observability add-on"
}
