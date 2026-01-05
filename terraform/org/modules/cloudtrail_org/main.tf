locals {
  trail_bucket_name = var.bucket_name
}

resource "aws_s3_bucket" "trail" {
  count         = var.create_bucket ? 1 : 0
  bucket        = var.bucket_name
  force_destroy = var.force_destroy
  tags = {
    Purpose = "org-cloudtrail"
  }
}

resource "aws_s3_bucket_versioning" "trail" {
  count  = var.create_bucket ? 1 : 0
  bucket = aws_s3_bucket.trail[0].id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "trail" {
  count  = var.create_bucket ? 1 : 0
  bucket = aws_s3_bucket.trail[0].id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = var.kms_key_arn != "" ? "aws:kms" : "AES256"
      kms_master_key_id = var.kms_key_arn != "" ? var.kms_key_arn : null
    }
    bucket_key_enabled = true
  }
}

resource "aws_s3_bucket_public_access_block" "trail" {
  count  = var.create_bucket ? 1 : 0
  bucket = aws_s3_bucket.trail[0].id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

data "aws_iam_policy_document" "trail_bucket" {
  statement {
    sid     = "AWSCloudTrailAclCheck"
    effect  = "Allow"
    actions = ["s3:GetBucketAcl"]
    principals {
      type        = "Service"
      identifiers = ["cloudtrail.amazonaws.com"]
    }
    resources = ["arn:aws:s3:::${local.trail_bucket_name}"]
  }

  statement {
    sid     = "AWSCloudTrailWrite"
    effect  = "Allow"
    actions = ["s3:PutObject"]
    principals {
      type        = "Service"
      identifiers = ["cloudtrail.amazonaws.com"]
    }
    resources = ["arn:aws:s3:::${local.trail_bucket_name}/${var.s3_key_prefix}/AWSLogs/*"]
    condition {
      test     = "StringEquals"
      variable = "s3:x-amz-acl"
      values   = ["bucket-owner-full-control"]
    }
  }
}

resource "aws_s3_bucket_policy" "trail" {
  count  = var.create_bucket ? 1 : 0
  bucket = aws_s3_bucket.trail[0].id
  policy = data.aws_iam_policy_document.trail_bucket.json
}

resource "aws_iam_role" "replication" {
  count = var.create_bucket && var.replica_bucket_arn != "" ? 1 : 0
  name  = "${var.trail_name}-replication"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "s3.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy" "replication" {
  count = var.create_bucket && var.replica_bucket_arn != "" ? 1 : 0
  role  = aws_iam_role.replication[0].id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["s3:GetReplicationConfiguration", "s3:ListBucket"]
        Resource = ["arn:aws:s3:::${local.trail_bucket_name}"]
      },
      {
        Effect   = "Allow"
        Action   = [
          "s3:GetObjectVersion",
          "s3:GetObjectVersionAcl",
          "s3:GetObjectVersionForReplication",
          "s3:GetObjectVersionTagging",
          "s3:GetObjectRetention",
          "s3:GetObjectLegalHold"
        ]
        Resource = ["arn:aws:s3:::${local.trail_bucket_name}/*"]
      },
      {
        Effect   = "Allow"
        Action   = [
          "s3:ReplicateObject",
          "s3:ReplicateDelete",
          "s3:ReplicateTags",
          "s3:ObjectOwnerOverrideToBucketOwner"
        ]
        Resource = [var.replica_bucket_arn, "${var.replica_bucket_arn}/*"]
      }
    ]
  })
}

resource "aws_s3_bucket_replication_configuration" "trail" {
  count = var.create_bucket && var.replica_bucket_arn != "" ? 1 : 0

  bucket = aws_s3_bucket.trail[0].id
  role   = aws_iam_role.replication[0].arn

  rule {
    id     = "replicate-cloudtrail"
    status = "Enabled"
    destination {
      bucket        = var.replica_bucket_arn
      storage_class = "STANDARD"
      encryption_configuration {
        replica_kms_key_id = var.replica_kms_key_arn != "" ? var.replica_kms_key_arn : null
      }
    }
  }

  depends_on = [aws_s3_bucket_versioning.trail]
}

resource "aws_cloudtrail" "org" {
  name                          = var.trail_name
  is_organization_trail         = true
  is_multi_region_trail         = true
  enable_log_file_validation    = true
  include_global_service_events = true
  s3_bucket_name                = local.trail_bucket_name
  s3_key_prefix                 = var.s3_key_prefix
  kms_key_id                    = var.kms_key_arn != "" ? var.kms_key_arn : null

  depends_on = var.create_bucket ? [aws_s3_bucket_policy.trail] : []
}
