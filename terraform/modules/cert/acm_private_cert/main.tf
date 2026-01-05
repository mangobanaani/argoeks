resource "aws_acm_certificate" "this" {
  domain_name               = var.domain_name
  subject_alternative_names = var.subject_alternative_names
  certificate_authority_arn = var.certificate_authority_arn
  tags                      = var.tags
}

output "certificate_arn" { value = aws_acm_certificate.this.arn }
