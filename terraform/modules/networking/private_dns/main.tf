resource "aws_route53_zone" "private" {
  count = var.enabled ? 1 : 0
  name  = var.domain
  vpc { vpc_id = var.vpc_ids[0] }
  tags = var.tags
}

resource "aws_route53_vpc_association_authorization" "auth" {
  for_each = var.enabled && length(var.vpc_ids) > 1 ? toset(slice(var.vpc_ids, 1, length(var.vpc_ids))) : []
  vpc_id   = each.key
  zone_id  = aws_route53_zone.private[0].id
}

resource "aws_route53_zone_association" "assoc" {
  for_each   = var.enabled && length(var.vpc_ids) > 1 ? toset(slice(var.vpc_ids, 1, length(var.vpc_ids))) : []
  vpc_id     = each.key
  zone_id    = aws_route53_zone.private[0].id
  depends_on = [aws_route53_vpc_association_authorization.auth]
}

output "zone_id" { value = var.enabled ? aws_route53_zone.private[0].zone_id : null }
output "name" { value = var.enabled ? aws_route53_zone.private[0].name : null }
