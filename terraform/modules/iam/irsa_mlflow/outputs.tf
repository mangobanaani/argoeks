output "role_arn" {
  description = "IAM role ARN for MLflow service account"
  value       = aws_iam_role.mlflow.arn
}

output "role_name" {
  description = "IAM role name"
  value       = aws_iam_role.mlflow.name
}

output "service_account_annotation" {
  description = "Annotation to add to Kubernetes ServiceAccount"
  value       = "eks.amazonaws.com/role-arn: ${aws_iam_role.mlflow.arn}"
}
