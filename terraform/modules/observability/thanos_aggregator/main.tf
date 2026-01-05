terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
    }
    kubernetes = {
      source = "hashicorp/kubernetes"
    }
    helm = {
      source = "hashicorp/helm"
    }
    random = {
      source = "hashicorp/random"
    }
  }
}

locals {
  name = "thanos-${var.environment}"
}

resource "aws_kms_key" "thanos" {
  count               = var.enabled && var.create_bucket ? 1 : 0
  description         = "KMS key for Thanos object storage (${var.environment})"
  enable_key_rotation = true
}

resource "aws_s3_bucket" "thanos" {
  count         = var.enabled && var.create_bucket ? 1 : 0
  bucket        = var.bucket_name != "" ? var.bucket_name : "${local.name}-${var.region}-${random_id.suffix[0].hex}"
  force_destroy = false
}

resource "random_id" "suffix" {
  count       = var.enabled && var.create_bucket ? 1 : 0
  byte_length = 3
}

resource "aws_s3_bucket_versioning" "thanos" {
  count  = var.enabled && var.create_bucket ? 1 : 0
  bucket = aws_s3_bucket.thanos[0].id
  versioning_configuration { status = "Enabled" }
}

resource "aws_s3_bucket_lifecycle_configuration" "thanos" {
  count  = var.enabled && var.create_bucket ? 1 : 0
  bucket = aws_s3_bucket.thanos[0].id

  rule {
    id     = "transition-to-intelligent-tiering"
    status = "Enabled"

    transition {
      days          = 90
      storage_class = "INTELLIGENT_TIERING"
    }
  }

  rule {
    id     = "expire-old-metrics"
    status = "Enabled"

    expiration {
      days = 395  # 13 months retention for metrics
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

resource "aws_s3_bucket_server_side_encryption_configuration" "thanos" {
  count  = var.enabled && var.create_bucket ? 1 : 0
  bucket = aws_s3_bucket.thanos[0].id
  rule {
    apply_server_side_encryption_by_default {
      kms_master_key_id = aws_kms_key.thanos[0].arn
      sse_algorithm     = "aws:kms"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "thanos" {
  count                   = var.enabled && var.create_bucket ? 1 : 0
  bucket                  = aws_s3_bucket.thanos[0].id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

locals {
  bucket_selected = var.create_bucket ? (length(aws_s3_bucket.thanos) > 0 ? aws_s3_bucket.thanos[0].bucket : var.bucket_name) : var.bucket_name
}

resource "aws_s3_bucket_policy" "thanos" {
  count  = var.enabled && var.create_bucket && length(var.bucket_role_arns) > 0 ? 1 : 0
  bucket = aws_s3_bucket.thanos[0].id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "AllowIRSAAccess"
        Effect    = "Allow"
        Principal = { AWS = var.bucket_role_arns }
        Action    = ["s3:ListBucket"]
        Resource  = [aws_s3_bucket.thanos[0].arn]
      },
      {
        Sid       = "AllowIRSAObjectAccess"
        Effect    = "Allow"
        Principal = { AWS = var.bucket_role_arns }
        Action    = ["s3:GetObject", "s3:PutObject", "s3:DeleteObject", "s3:AbortMultipartUpload", "s3:ListBucketMultipartUploads"]
        Resource  = ["${aws_s3_bucket.thanos[0].arn}/*"]
      },
      {
        Sid       = "DenyInsecureTransport"
        Effect    = "Deny"
        Principal = "*"
        Action    = "s3:*"
        Resource  = [aws_s3_bucket.thanos[0].arn, "${aws_s3_bucket.thanos[0].arn}/*"]
        Condition = { Bool = { "aws:SecureTransport" = false } }
      }
    ]
  })
}

resource "kubernetes_namespace_v1" "monitoring" {
  count = var.enabled ? 1 : 0
  metadata { name = var.namespace }
}

resource "kubernetes_secret_v1" "thanos_objstore" {
  count = var.enabled ? 1 : 0
  metadata {
    name      = "thanos-objstore"
    namespace = var.namespace
  }
  data = {
    # Thanos reads this file to configure S3 access. Credentials are omitted to use IRSA/instance profile.
    "objstore.yml" = yamlencode({
      type = "s3"
      config = {
        bucket   = local.bucket_selected
        endpoint = "s3.${var.region}.amazonaws.com"
      }
    })
  }
}

resource "helm_release" "thanos" {
  count      = var.enabled ? 1 : 0
  name       = "thanos"
  namespace  = var.namespace
  repository = "https://charts.bitnami.com/bitnami"
  chart      = "thanos"
  version    = var.thanos_chart_version
  timeout    = 600
  wait       = true
  values = [
    yamlencode({
      existingObjstoreSecret = kubernetes_secret_v1.thanos_objstore[0].metadata[0].name
      metrics                = { enabled = true }
      query                  = { enabled = true }
      compactor              = { enabled = true }
      storegateway           = { enabled = true }
      receive = {
        enabled  = true
        replicas = 2
      }
      bucketweb = { enabled = true }
      serviceAccount = {
        create      = true
        annotations = var.service_account_annotations
      }
    })
  ]
  depends_on = [kubernetes_secret_v1.thanos_objstore, kubernetes_namespace_v1.monitoring]
}

output "thanos_bucket" { value = local.bucket_selected }
output "thanos_bucket_arn" { value = var.create_bucket && length(aws_s3_bucket.thanos) > 0 ? aws_s3_bucket.thanos[0].arn : null }
output "kms_key_arn" { value = var.create_bucket && length(aws_kms_key.thanos) > 0 ? aws_kms_key.thanos[0].arn : null }
