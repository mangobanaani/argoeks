# IRSA for MLflow Tracking Server
# Grants access to S3 artifacts bucket and RDS database

data "aws_iam_policy_document" "mlflow_assume" {
  statement {
    effect = "Allow"

    principals {
      type        = "Federated"
      identifiers = [var.oidc_provider_arn]
    }

    actions = ["sts:AssumeRoleWithWebIdentity"]

    condition {
      test     = "StringEquals"
      variable = "${replace(var.oidc_provider_arn, "/^(.*provider/)/", "")}:sub"
      values   = ["system:serviceaccount:${var.namespace}:${var.service_account}"]
    }

    condition {
      test     = "StringEquals"
      variable = "${replace(var.oidc_provider_arn, "/^(.*provider/)/", "")}:aud"
      values   = ["sts.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "mlflow" {
  name               = "${var.cluster_name}-mlflow-${var.namespace}"
  assume_role_policy = data.aws_iam_policy_document.mlflow_assume.json

  tags = merge(
    var.tags,
    {
      Name      = "${var.cluster_name}-mlflow"
      Namespace = var.namespace
      Component = "MLflow"
    }
  )
}

# S3 access for artifacts
data "aws_iam_policy_document" "mlflow_s3" {
  statement {
    effect = "Allow"
    actions = [
      "s3:GetObject",
      "s3:PutObject",
      "s3:DeleteObject",
      "s3:ListBucket"
    ]
    resources = [
      var.s3_bucket_arn,
      "${var.s3_bucket_arn}/*"
    ]
  }

  statement {
    effect = "Allow"
    actions = [
      "kms:Decrypt",
      "kms:GenerateDataKey"
    ]
    resources = var.kms_key_arn != null ? [var.kms_key_arn] : []
  }
}

resource "aws_iam_policy" "mlflow_s3" {
  name        = "${var.cluster_name}-mlflow-s3-${var.namespace}"
  description = "MLflow S3 access for artifacts"
  policy      = data.aws_iam_policy_document.mlflow_s3.json

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "mlflow_s3" {
  role       = aws_iam_role.mlflow.name
  policy_arn = aws_iam_policy.mlflow_s3.arn
}

# RDS IAM auth (optional)
data "aws_iam_policy_document" "mlflow_rds" {
  count = var.enable_rds_iam_auth ? 1 : 0

  statement {
    effect = "Allow"
    actions = [
      "rds-db:connect"
    ]
    resources = [
      "arn:aws:rds-db:${data.aws_region.current.id}:${data.aws_caller_identity.current.account_id}:dbuser:${var.rds_db_identifier}/${var.rds_db_username}"
    ]
  }
}

resource "aws_iam_policy" "mlflow_rds" {
  count = var.enable_rds_iam_auth ? 1 : 0

  name        = "${var.cluster_name}-mlflow-rds-${var.namespace}"
  description = "MLflow RDS IAM authentication"
  policy      = data.aws_iam_policy_document.mlflow_rds[0].json

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "mlflow_rds" {
  count = var.enable_rds_iam_auth ? 1 : 0

  role       = aws_iam_role.mlflow.name
  policy_arn = aws_iam_policy.mlflow_rds[0].arn
}

data "aws_region" "current" {}
data "aws_caller_identity" "current" {}
