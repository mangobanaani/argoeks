output "endpoint_ids" {
  description = "Map of endpoint names to endpoint IDs"
  value       = { for k, v in aws_vpc_endpoint.mlops : k => v.id }
}

output "endpoint_dns_entries" {
  description = "Map of endpoint names to DNS entries"
  value       = { for k, v in aws_vpc_endpoint.mlops : k => v.dns_entry }
}

output "security_group_id" {
  description = "Security group ID for VPC endpoints"
  value       = aws_security_group.vpc_endpoints.id
}
