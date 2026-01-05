data "aws_caller_identity" "current" {}

locals {
  names          = var.cluster_names
  oidc_providers = length(var.cluster_oidc_providers) > 0 ? var.cluster_oidc_providers : { for name, url in var.cluster_oidc_issuer_urls : name => replace(url, "https://", "") }
}

resource "aws_iam_policy" "secrets_read" {
  name = "eso-read-secrets"
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      { Effect = "Allow", Action = ["secretsmanager:ListSecrets"], Resource = "*" },
      { Effect = "Allow", Action = ["secretsmanager:GetSecretValue", "secretsmanager:DescribeSecret"], Resource = concat(var.secret_arns, ["arn:aws:secretsmanager:*:*:secret:${var.secret_name_prefix}*"]) }
    ]
  })
}

resource "aws_iam_role" "eso" {
  for_each = toset(local.names)
  name     = "external-secrets-${each.value}"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect    = "Allow",
      Action    = "sts:AssumeRoleWithWebIdentity",
      Principal = { Federated = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:oidc-provider/${local.oidc_providers[each.value]}" },
      Condition = {
        StringEquals = {
          "${local.oidc_providers[each.value]}:aud" = "sts.amazonaws.com",
          "${local.oidc_providers[each.value]}:sub" = "system:serviceaccount:external-secrets:external-secrets"
        }
      }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "attach" {
  for_each   = toset(local.names)
  role       = aws_iam_role.eso[each.key].name
  policy_arn = aws_iam_policy.secrets_read.arn
}

output "role_arns" { value = { for k, v in aws_iam_role.eso : k => v.arn } }
