resource "aws_vpc_endpoint" "this" {
  vpc_id              = var.vpc_id
  service_name        = var.service_name
  vpc_endpoint_type   = "Interface"
  private_dns_enabled = var.private_dns_enabled
  subnet_ids          = var.subnet_ids
  security_group_ids  = var.security_group_ids
}

resource "aws_route53_record" "vpce" {
  count   = var.zone_id != "" && var.dns_name != "" ? 1 : 0
  zone_id = var.zone_id
  name    = var.dns_name
  type    = "A"
  alias {
    name                   = aws_vpc_endpoint.this.dns_entry[0].dns_name
    zone_id                = aws_vpc_endpoint.this.dns_entry[0].hosted_zone_id
    evaluate_target_health = false
  }
}

output "endpoint_id" { value = aws_vpc_endpoint.this.id }
output "dns_entries" { value = aws_vpc_endpoint.this.dns_entry }
