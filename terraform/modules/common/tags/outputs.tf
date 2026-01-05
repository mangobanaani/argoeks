output "tags" {
  description = "Complete merged tag map for all resources"
  value       = local.all_tags
}

output "cost_allocation_tags" {
  description = "Cost allocation tags only"
  value       = local.cost_allocation_tags
}

output "technical_tags" {
  description = "Technical tags only"
  value       = local.technical_tags
}

output "compliance_tags" {
  description = "Compliance tags only"
  value       = local.compliance_tags
}
