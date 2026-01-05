output "artifact_bucket_name" {
  description = "MLflow artifacts S3 bucket name"
  value       = aws_s3_bucket.artifacts.id
}

output "artifact_bucket_arn" {
  description = "MLflow artifacts S3 bucket ARN"
  value       = aws_s3_bucket.artifacts.arn
}

output "rds_endpoint" {
  description = "RDS endpoint"
  value       = aws_db_instance.mlflow.endpoint
}

output "rds_address" {
  description = "RDS address"
  value       = aws_db_instance.mlflow.address
}

output "rds_identifier" {
  description = "RDS identifier"
  value       = aws_db_instance.mlflow.identifier
}

output "rds_arn" {
  description = "RDS ARN"
  value       = aws_db_instance.mlflow.arn
}

output "db_secret_arn" {
  description = "Secrets Manager ARN for database credentials"
  value       = aws_secretsmanager_secret.mlflow_db.arn
}

output "db_name" {
  description = "Database name"
  value       = local.db_name
}

output "db_username" {
  description = "Database username"
  value       = local.db_username
}
