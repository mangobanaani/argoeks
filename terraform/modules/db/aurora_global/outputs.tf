output "primary_writer_endpoint" { value = aws_rds_cluster.primary.endpoint }
output "secondary_reader_endpoint" { value = aws_rds_cluster.secondary.reader_endpoint }
output "primary_instance_ids" { value = [for i in aws_rds_cluster_instance.primary : i.id] }
output "secondary_instance_ids" { value = [for i in aws_rds_cluster_instance.secondary : i.id] }
output "secret_arn" { value = var.create_password_secret ? aws_secretsmanager_secret.db[0].arn : null }
