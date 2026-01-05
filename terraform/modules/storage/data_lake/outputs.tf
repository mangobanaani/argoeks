output "bucket_name" {
  description = "Data lake bucket name"
  value       = aws_s3_bucket.data_lake.id
}

output "bucket_arn" {
  description = "Data lake bucket ARN"
  value       = aws_s3_bucket.data_lake.arn
}

output "bucket_domain_name" {
  description = "Data lake bucket domain name"
  value       = aws_s3_bucket.data_lake.bucket_domain_name
}

output "zones" {
  description = "List of data lake zones"
  value       = local.zones
}

output "replica_bucket_arn" {
  description = "Replica bucket ARN (if replication enabled)"
  value       = var.enable_replication && var.replication_region != null ? aws_s3_bucket.replica[0].arn : null
}
