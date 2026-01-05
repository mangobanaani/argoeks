output "namespace" {
  description = "Kubernetes namespace where KEDA is installed"
  value       = local.namespace
}

output "iam_role_arn" {
  description = "IAM role ARN for KEDA service account"
  value       = var.enable_irsa ? aws_iam_role.keda[0].arn : null
}

output "service_account_name" {
  description = "Name of the KEDA service account"
  value       = var.service_account_name
}

output "helm_release_name" {
  description = "Name of the KEDA Helm release"
  value       = var.install ? helm_release.keda[0].name : null
}

output "helm_release_version" {
  description = "Version of the KEDA Helm release"
  value       = var.install ? helm_release.keda[0].version : null
}
