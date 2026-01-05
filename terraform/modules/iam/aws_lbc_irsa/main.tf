data "aws_caller_identity" "current" {}

locals {
  issuer_hostpath      = replace(var.oidc_issuer_url, "https://", "")
  lb_controller_policy = var.policy_json != "" ? var.policy_json : file("${path.module}/policy.json")
}

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
      values = [
        "system:serviceaccount:kube-system:aws-load-balancer-controller"
      ]
    }
  }
}

resource "aws_iam_role" "this" {
  name               = var.name
  assume_role_policy = data.aws_iam_policy_document.assume.json
  tags               = var.tags
}

resource "aws_iam_policy" "custom" {
  count  = var.use_aws_managed_policy ? 0 : 1
  name   = "${var.name}-policy"
  policy = local.lb_controller_policy
}

resource "aws_iam_role_policy_attachment" "attach_managed" {
  count      = var.use_aws_managed_policy ? 1 : 0
  role       = aws_iam_role.this.name
  policy_arn = "arn:aws:iam::aws:policy/AWSLoadBalancerControllerIAMPolicy"
}

resource "aws_iam_role_policy_attachment" "attach_custom" {
  count      = var.use_aws_managed_policy ? 0 : 1
  role       = aws_iam_role.this.name
  policy_arn = aws_iam_policy.custom[0].arn
}

output "role_arn" { value = aws_iam_role.this.arn }
output "annotations" { value = { "eks.amazonaws.com/role-arn" = aws_iam_role.this.arn } }
