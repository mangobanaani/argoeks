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

data "aws_iam_policy_document" "s3" {
  statement {
    sid       = "ListBuckets"
    effect    = "Allow"
    actions   = ["s3:ListAllMyBuckets"]
    resources = ["*"]
  }
  statement {
    sid       = "BucketAccess"
    effect    = "Allow"
    actions   = ["s3:ListBucket"]
    resources = var.bucket_arns
  }
  statement {
    sid       = "ObjectAccess"
    effect    = "Allow"
    actions   = var.read_only ? ["s3:GetObject", "s3:GetObjectAttributes", "s3:ListBucketMultipartUploads"] : ["s3:GetObject", "s3:PutObject", "s3:DeleteObject", "s3:GetObjectAttributes", "s3:AbortMultipartUpload", "s3:ListBucketMultipartUploads"]
    resources = [for b in var.bucket_arns : "${b}/*"]
  }
  dynamic "statement" {
    for_each = length(var.kms_key_arns) > 0 ? [1] : []
    content {
      sid       = "KMSDecrypt"
      effect    = "Allow"
      actions   = var.read_only ? ["kms:Decrypt"] : ["kms:Decrypt", "kms:Encrypt", "kms:GenerateDataKey"]
      resources = var.kms_key_arns
    }
  }
}

resource "aws_iam_policy" "this" {
  name   = "${var.name}-policy"
  policy = data.aws_iam_policy_document.s3.json
}

resource "aws_iam_role_policy_attachment" "attach" {
  role       = aws_iam_role.this.name
  policy_arn = aws_iam_policy.this.arn
}

output "role_arn" { value = aws_iam_role.this.arn }
output "annotations" { value = { "eks.amazonaws.com/role-arn" = aws_iam_role.this.arn } }
