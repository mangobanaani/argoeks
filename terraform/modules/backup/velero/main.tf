terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">= 2.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = ">= 2.0"
    }
  }
}

locals {
  name = "velero-${var.cluster_name}"
}

# S3 bucket for Velero backups
resource "aws_s3_bucket" "velero" {
  count  = var.create_bucket ? 1 : 0
  bucket = var.bucket_name != "" ? var.bucket_name : "${local.name}-${data.aws_caller_identity.current.account_id}"

  tags = merge(
    var.tags,
    {
      Name    = local.name
      Purpose = "Velero Kubernetes Backup"
    }
  )
}

resource "aws_s3_bucket_versioning" "velero" {
  count  = var.create_bucket ? 1 : 0
  bucket = aws_s3_bucket.velero[0].id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "velero" {
  count  = var.create_bucket ? 1 : 0
  bucket = aws_s3_bucket.velero[0].id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = aws_kms_key.velero[0].arn
    }
    bucket_key_enabled = true
  }
}

resource "aws_s3_bucket_public_access_block" "velero" {
  count  = var.create_bucket ? 1 : 0
  bucket = aws_s3_bucket.velero[0].id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_lifecycle_configuration" "velero" {
  count  = var.create_bucket ? 1 : 0
  bucket = aws_s3_bucket.velero[0].id

  rule {
    id     = "transition-old-backups"
    status = "Enabled"

    transition {
      days          = 30
      storage_class = "STANDARD_IA"
    }

    transition {
      days          = 90
      storage_class = "GLACIER_IR"
    }
  }

  rule {
    id     = "expire-old-backups"
    status = "Enabled"

    expiration {
      days = var.backup_retention_days
    }
  }

  rule {
    id     = "cleanup-incomplete-uploads"
    status = "Enabled"

    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }
}

# KMS key for encryption
resource "aws_kms_key" "velero" {
  count               = var.create_bucket ? 1 : 0
  description         = "KMS key for Velero backups (${var.cluster_name})"
  enable_key_rotation = true

  tags = merge(
    var.tags,
    {
      Name = "${local.name}-kms"
    }
  )
}

resource "aws_kms_alias" "velero" {
  count         = var.create_bucket ? 1 : 0
  name          = "alias/${local.name}"
  target_key_id = aws_kms_key.velero[0].key_id
}

# IAM role for Velero (IRSA)
data "aws_caller_identity" "current" {}

data "aws_iam_policy_document" "velero_assume" {
  statement {
    effect = "Allow"
    principals {
      type        = "Federated"
      identifiers = [var.oidc_provider_arn]
    }
    actions = ["sts:AssumeRoleWithWebIdentity"]
    condition {
      test     = "StringEquals"
      variable = "${replace(var.oidc_issuer_url, "https://", "")}:sub"
      values   = ["system:serviceaccount:${var.namespace}:velero"]
    }
    condition {
      test     = "StringEquals"
      variable = "${replace(var.oidc_issuer_url, "https://", "")}:aud"
      values   = ["sts.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "velero" {
  name               = "${local.name}-irsa"
  assume_role_policy = data.aws_iam_policy_document.velero_assume.json

  tags = merge(
    var.tags,
    {
      Name = "${local.name}-irsa"
    }
  )
}

data "aws_iam_policy_document" "velero" {
  statement {
    sid    = "VeleroS3Access"
    effect = "Allow"
    actions = [
      "s3:GetObject",
      "s3:DeleteObject",
      "s3:PutObject",
      "s3:AbortMultipartUpload",
      "s3:ListMultipartUploadParts"
    ]
    resources = [
      var.create_bucket ? "${aws_s3_bucket.velero[0].arn}/*" : "${var.bucket_arn}/*"
    ]
  }

  statement {
    sid    = "VeleroS3List"
    effect = "Allow"
    actions = [
      "s3:ListBucket"
    ]
    resources = [
      var.create_bucket ? aws_s3_bucket.velero[0].arn : var.bucket_arn
    ]
  }

  statement {
    sid    = "VeleroEC2"
    effect = "Allow"
    actions = [
      "ec2:DescribeVolumes",
      "ec2:DescribeSnapshots",
      "ec2:CreateTags",
      "ec2:CreateVolume",
      "ec2:CreateSnapshot",
      "ec2:DeleteSnapshot"
    ]
    resources = ["*"]
  }

  statement {
    sid    = "VeleroKMS"
    effect = "Allow"
    actions = [
      "kms:Decrypt",
      "kms:Encrypt",
      "kms:GenerateDataKey",
      "kms:DescribeKey"
    ]
    resources = var.create_bucket ? [aws_kms_key.velero[0].arn] : [var.kms_key_arn]
  }
}

resource "aws_iam_policy" "velero" {
  name   = "${local.name}-policy"
  policy = data.aws_iam_policy_document.velero.json

  tags = merge(
    var.tags,
    {
      Name = "${local.name}-policy"
    }
  )
}

resource "aws_iam_role_policy_attachment" "velero" {
  role       = aws_iam_role.velero.name
  policy_arn = aws_iam_policy.velero.arn
}

# Kubernetes namespace
resource "kubernetes_namespace_v1" "velero" {
  count = var.install ? 1 : 0

  metadata {
    name = var.namespace
    labels = {
      "pod-security.kubernetes.io/enforce" = "privileged"
    }
  }
}

# Helm release
resource "helm_release" "velero" {
  count = var.install ? 1 : 0

  name       = "velero"
  repository = "https://vmware-tanzu.github.io/helm-charts"
  chart      = "velero"
  version    = var.velero_version
  namespace  = var.namespace

  values = [yamlencode({
    configuration = {
      backupStorageLocation = [{
        name     = "default"
        provider = "aws"
        bucket   = var.create_bucket ? aws_s3_bucket.velero[0].id : var.bucket_name
        config = {
          region           = var.region
          kmsKeyId         = var.create_bucket ? aws_kms_key.velero[0].arn : var.kms_key_arn
          s3ForcePathStyle = false
        }
      }]

      volumeSnapshotLocation = [{
        name     = "default"
        provider = "aws"
        config = {
          region = var.region
        }
      }]

      defaultBackupStorageLocation = "default"
      defaultVolumeSnapshotLocations = "default"
    }

    credentials = {
      useSecret = false  # Using IRSA instead
    }

    serviceAccount = {
      server = {
        create = true
        name   = "velero"
        annotations = {
          "eks.amazonaws.com/role-arn" = aws_iam_role.velero.arn
        }
      }
    }

    initContainers = [{
      name  = "velero-plugin-for-aws"
      image = "velero/velero-plugin-for-aws:${var.velero_plugin_version}"
      volumeMounts = [{
        mountPath = "/target"
        name      = "plugins"
      }]
    }]

    schedules = var.backup_schedules

    metrics = {
      enabled        = true
      serviceMonitor = {
        enabled = var.enable_service_monitor
      }
    }
  })]

  depends_on = [kubernetes_namespace_v1.velero]
}
