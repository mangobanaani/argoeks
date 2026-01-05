resource "aws_vpc_endpoint_service" "this" {
  acceptance_required        = var.require_acceptance
  network_load_balancer_arns = [var.nlb_arn]
  allowed_principals         = var.allowed_principals
  tags                       = merge(var.tags, { Name = var.name })
}

output "service_name" { value = aws_vpc_endpoint_service.this.service_name }
output "service_id" { value = aws_vpc_endpoint_service.this.id }
