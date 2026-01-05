data "aws_caller_identity" "current" {}

locals {
  names           = var.cluster_names
  oidc_providers  = length(var.cluster_oidc_providers) > 0 ? var.cluster_oidc_providers : { for name, url in var.cluster_oidc_issuer_urls : name => replace(url, "https://", "") }
}

resource "aws_iam_policy" "route53" {
  name = "${var.policy_prefix}-${var.zone_id}"
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      { Effect = "Allow", Action = ["route53:ListHostedZones", "route53:ListResourceRecordSets", "route53:ListHostedZonesByName"], Resource = "*" },
      { Effect = "Allow", Action = ["route53:ChangeResourceRecordSets"], Resource = "arn:aws:route53:::hostedzone/${var.zone_id}" }
    ]
  })
}

resource "aws_iam_role" "external_dns" {
  for_each = toset(local.names)
  name     = "external-dns-${each.value}"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect    = "Allow",
      Action    = "sts:AssumeRoleWithWebIdentity",
      Principal = { Federated = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:oidc-provider/${local.oidc_providers[each.value]}" },
      Condition = {
        StringEquals = {
          "${local.oidc_providers[each.value]}:aud" = "sts.amazonaws.com",
          "${local.oidc_providers[each.value]}:sub" = "system:serviceaccount:kube-system:external-dns"
        }
      }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "attach" {
  for_each   = toset(local.names)
  role       = aws_iam_role.external_dns[each.key].name
  policy_arn = aws_iam_policy.route53.arn
}

output "role_arns" {
  value = { for k, v in aws_iam_role.external_dns : k => v.arn }
}
