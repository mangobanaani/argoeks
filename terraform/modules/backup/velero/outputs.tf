output "bucket_id" {
  description = "S3 bucket ID for Velero backups"
  value       = var.create_bucket ? (length(aws_s3_bucket.velero) > 0 ? aws_s3_bucket.velero[0].id : null) : var.bucket_name
}

output "bucket_arn" {
  description = "S3 bucket ARN for Velero backups"
  value       = var.create_bucket ? (length(aws_s3_bucket.velero) > 0 ? aws_s3_bucket.velero[0].arn : null) : var.bucket_arn
}

output "kms_key_id" {
  description = "KMS key ID for backup encryption"
  value       = var.create_bucket ? (length(aws_kms_key.velero) > 0 ? aws_kms_key.velero[0].id : null) : null
}

output "iam_role_arn" {
  description = "IAM role ARN for Velero IRSA"
  value       = aws_iam_role.velero.arn
}

output "namespace" {
  description = "Kubernetes namespace for Velero"
  value       = var.namespace
}
