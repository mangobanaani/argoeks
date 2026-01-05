data "aws_caller_identity" "current" {}

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

data "aws_iam_policy_document" "ddb" {
  statement {
    sid    = "TableAccess"
    effect = "Allow"
    actions = var.read_only ? ["dynamodb:GetItem", "dynamodb:BatchGetItem", "dynamodb:Query", "dynamodb:Scan"] : [
      "dynamodb:GetItem", "dynamodb:BatchGetItem", "dynamodb:Query", "dynamodb:Scan",
      "dynamodb:PutItem", "dynamodb:BatchWriteItem", "dynamodb:UpdateItem", "dynamodb:DeleteItem"
    ]
    resources = concat(var.table_arns, [for a in var.table_arns : "${a}/index/*"])
  }
}

resource "aws_iam_policy" "this" {
  name   = "${var.name}-ddb-policy"
  policy = data.aws_iam_policy_document.ddb.json
}

resource "aws_iam_role_policy_attachment" "attach" {
  role       = aws_iam_role.this.name
  policy_arn = aws_iam_policy.this.arn
}

output "annotations" { value = { "eks.amazonaws.com/role-arn" = aws_iam_role.this.arn } }
