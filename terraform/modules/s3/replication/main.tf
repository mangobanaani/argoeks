data "aws_caller_identity" "current" {}

resource "aws_iam_role" "replication" {
  name = "s3-replication-${replace(var.source_bucket, ".", "-")}"
  assume_role_policy = jsonencode({
    Version   = "2012-10-17",
    Statement = [{ Effect = "Allow", Principal = { Service = "s3.amazonaws.com" }, Action = "sts:AssumeRole" }]
  })
}

resource "aws_iam_role_policy" "replication" {
  role = aws_iam_role.replication.id
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      { Effect = "Allow", Action = ["s3:GetReplicationConfiguration", "s3:ListBucket"], Resource = ["arn:aws:s3:::${var.source_bucket}"] },
      { Effect = "Allow", Action = ["s3:GetObjectVersion", "s3:GetObjectVersionForReplication", "s3:GetObjectVersionAcl", "s3:GetObjectVersionTagging"], Resource = ["arn:aws:s3:::${var.source_bucket}/*"] },
      { Effect = "Allow", Action = ["s3:ReplicateObject", "s3:ReplicateDelete", "s3:ReplicateTags", "s3:ObjectOwnerOverrideToBucketOwner"], Resource = ["arn:aws:s3:::${var.destination_bucket}/*"] },
      { Effect = "Allow", Action = ["s3:ListBucket"], Resource = ["arn:aws:s3:::${var.destination_bucket}"] }
    ]
  })
}

resource "aws_s3_bucket_replication_configuration" "this" {
  role   = aws_iam_role.replication.arn
  bucket = var.source_bucket
  rule {
    id     = "replicate-to-${var.destination_bucket}"
    status = "Enabled"
    destination {
      bucket        = "arn:aws:s3:::${var.destination_bucket}"
      storage_class = "STANDARD"
      dynamic "encryption_configuration" {
        for_each = var.kms_key_arn != null ? [1] : []
        content {
          replica_kms_key_id = var.kms_key_arn
        }
      }
      replication_time { status = "Disabled" }
      metrics { status = "Disabled" }
    }
    filter { prefix = "" }
  }
}

output "role_arn" { value = aws_iam_role.replication.arn }
