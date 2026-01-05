output "ou_ids" {
  description = "Map of OU name => OU ID"
  value       = { for name, ou in aws_organizations_organizational_unit.ou : name => ou.id }
}
