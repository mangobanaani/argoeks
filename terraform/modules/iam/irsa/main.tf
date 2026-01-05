locals {
  issuer_hostpath = replace(var.oidc_issuer_url, "https://", "")
}

data "aws_iam_policy_document" "assume" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    principals {

      type = "Federated"

      identifiers = ["arn:aws:iam::${data.aws_caller_identity.this.account_id}:oidc-provider/${local.issuer_hostpath}"]

    }
    condition {
      test     = "StringEquals"
      variable = "${local.issuer_hostpath}:sub"
      values   = ["system:serviceaccount:${var.namespace}:${var.service_account}"]
    }
  }
}

data "aws_caller_identity" "this" {}

resource "aws_iam_role" "this" {
  name               = var.name
  assume_role_policy = data.aws_iam_policy_document.assume.json
  tags               = var.tags
}

resource "aws_iam_policy" "this" {
  name   = "${var.name}-policy"
  policy = var.policy_json
}

resource "aws_iam_role_policy_attachment" "this" {
  role       = aws_iam_role.this.name
  policy_arn = aws_iam_policy.this.arn
}

output "role_arn" { value = aws_iam_role.this.arn }
output "annotations" { value = { "eks.amazonaws.com/role-arn" = aws_iam_role.this.arn } }
