output "s3_role_arns" {
  description = "Map of workload names to S3 access IAM role ARNs"
  value       = { for k, v in module.irsa_s3 : k => v.role_arn }
}

output "dynamodb_role_arns" {
  description = "Map of workload names to DynamoDB access IAM role ARNs"
  value       = { for k, v in module.irsa_dynamodb : k => v.role_arn }
}

output "rds_role_arns" {
  description = "Map of workload names to RDS access IAM role ARNs"
  value       = { for k, v in module.irsa_rds : k => v.role_arn }
}

output "all_role_arns" {
  description = "Map of workload names to all their IAM role ARNs"
  value = {
    for name in keys(local.workloads) : name => {
      s3       = try(module.irsa_s3[name].role_arn, null)
      dynamodb = try(module.irsa_dynamodb[name].role_arn, null)
      rds      = try(module.irsa_rds[name].role_arn, null)
    }
  }
}

output "service_accounts" {
  description = "Map of created Kubernetes service accounts"
  value = {
    for k, v in kubernetes_service_account_v1.workload : k => {
      name      = v.metadata[0].name
      namespace = v.metadata[0].namespace
    }
  }
}

output "namespaces" {
  description = "List of created Kubernetes namespaces"
  value       = [for v in kubernetes_namespace_v1.workload : v.metadata[0].name]
}
