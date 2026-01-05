data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

locals { issuer_hostpath = replace(var.oidc_issuer_url, "https://", "") }

data "aws_iam_policy_document" "assume" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    principals {

      type = "Federated"

      identifiers = ["arn:aws:iam::${data.aws_caller_identity.current.account_id}:oidc-provider/${local.issuer_hostpath}"]

    }
    condition {
      test     = "StringEquals"
      variable = "${local.issuer_hostpath}:sub"
      values   = ["system:serviceaccount:${var.namespace}:${var.service_account}"]
    }
  }
}

resource "aws_iam_role" "this" {
  name               = var.name
  assume_role_policy = data.aws_iam_policy_document.assume.json
  tags               = var.tags
}

resource "aws_iam_policy" "connect" {
  name = "${var.name}-connect"
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect   = "Allow",
      Action   = "rds-db:connect",
      Resource = "arn:aws:rds-db:${data.aws_region.current.id}:${data.aws_caller_identity.current.account_id}:dbuser:${var.rds_resource_id}/${var.db_username}"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "attach" {
  role       = aws_iam_role.this.name
  policy_arn = aws_iam_policy.connect.arn
}

output "role_arn" { value = aws_iam_role.this.arn }
output "annotations" { value = { "eks.amazonaws.com/role-arn" = aws_iam_role.this.arn } }
