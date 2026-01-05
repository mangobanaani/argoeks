# S3 Data Lake with structured zones
# Zones: raw/, processed/, features/, models/, artifacts/

locals {
  bucket_name = "${var.bucket_prefix}-mlops-data-lake-${data.aws_caller_identity.current.account_id}"

  zones = [
    "raw",
    "processed",
    "features",
    "models",
    "artifacts"
  ]
}

data "aws_caller_identity" "current" {}

resource "aws_s3_bucket" "data_lake" {
  bucket = local.bucket_name

  tags = merge(
    var.tags,
    {
      Name        = local.bucket_name
      Purpose     = "MLOps Data Lake"
      Environment = var.bucket_prefix
    }
  )
}

resource "aws_s3_bucket_versioning" "data_lake" {
  count = var.enable_versioning ? 1 : 0

  bucket = aws_s3_bucket.data_lake.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "data_lake" {
  bucket = aws_s3_bucket.data_lake.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = var.kms_key_arn
    }
    bucket_key_enabled = true
  }
}

resource "aws_s3_bucket_public_access_block" "data_lake" {
  bucket = aws_s3_bucket.data_lake.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_lifecycle_configuration" "data_lake" {
  count = var.lifecycle_rules ? 1 : 0

  bucket = aws_s3_bucket.data_lake.id

  rule {
    id     = "transition-raw-data"
    status = "Enabled"

    filter {
      prefix = "raw/"
    }

    transition {
      days          = 90
      storage_class = "INTELLIGENT_TIERING"
    }

    transition {
      days          = 365
      storage_class = "GLACIER"
    }
  }

  rule {
    id     = "transition-processed-data"
    status = "Enabled"

    filter {
      prefix = "processed/"
    }

    transition {
      days          = 180
      storage_class = "INTELLIGENT_TIERING"
    }
  }

  rule {
    id     = "expire-artifacts"
    status = "Enabled"

    filter {
      prefix = "artifacts/experiments/"
    }

    expiration {
      days = 365
    }
  }
}

# Create zone prefixes (folders) in S3
resource "aws_s3_object" "zones" {
  for_each = toset(local.zones)

  bucket  = aws_s3_bucket.data_lake.id
  key     = "${each.value}/"
  content = ""

  tags = merge(
    var.tags,
    {
      Zone = each.value
    }
  )
}

# Optional cross-region replication
resource "aws_s3_bucket_replication_configuration" "data_lake" {
  count = var.enable_replication && var.replication_region != null ? 1 : 0

  depends_on = [aws_s3_bucket_versioning.data_lake]

  role   = aws_iam_role.replication[0].arn
  bucket = aws_s3_bucket.data_lake.id

  rule {
    id     = "replicate-all"
    status = "Enabled"

    destination {
      bucket        = aws_s3_bucket.replica[0].arn
      storage_class = "STANDARD_IA"

      encryption_configuration {
        replica_kms_key_id = var.replica_kms_key_arn
      }
    }
  }
}

resource "aws_s3_bucket" "replica" {
  count = var.enable_replication && var.replication_region != null ? 1 : 0

  provider = aws.replica
  bucket   = "${local.bucket_name}-replica"

  tags = merge(
    var.tags,
    {
      Name    = "${local.bucket_name}-replica"
      Purpose = "MLOps Data Lake Replica"
      Type    = "Replica"
    }
  )
}

resource "aws_s3_bucket_versioning" "replica" {
  count = var.enable_replication && var.replication_region != null ? 1 : 0

  provider = aws.replica
  bucket   = aws_s3_bucket.replica[0].id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_iam_role" "replication" {
  count = var.enable_replication && var.replication_region != null ? 1 : 0

  name = "${var.bucket_prefix}-s3-replication-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "s3.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })

  tags = var.tags
}

resource "aws_iam_role_policy" "replication" {
  count = var.enable_replication && var.replication_region != null ? 1 : 0

  role = aws_iam_role.replication[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetReplicationConfiguration",
          "s3:ListBucket"
        ]
        Resource = aws_s3_bucket.data_lake.arn
      },
      {
        Effect = "Allow"
        Action = [
          "s3:GetObjectVersionForReplication",
          "s3:GetObjectVersionAcl",
          "s3:GetObjectVersionTagging"
        ]
        Resource = "${aws_s3_bucket.data_lake.arn}/*"
      },
      {
        Effect = "Allow"
        Action = [
          "s3:ReplicateObject",
          "s3:ReplicateDelete",
          "s3:ReplicateTags"
        ]
        Resource = "${aws_s3_bucket.replica[0].arn}/*"
      }
    ]
  })
}
