resource "aws_kms_key" "ct" {
  description         = "KMS for CloudTrail logs"
  enable_key_rotation = true
}

resource "aws_kms_alias" "ct" {
  name          = var.kms_key_alias
  target_key_id = aws_kms_key.ct.key_id
}

resource "aws_s3_bucket" "logs" {
  bucket        = var.s3_bucket_name
  force_destroy = false
}

resource "aws_s3_bucket_versioning" "logs" {
  bucket = aws_s3_bucket.logs.id
  versioning_configuration { status = "Enabled" }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "logs" {
  bucket = aws_s3_bucket.logs.id
  rule {

    apply_server_side_encryption_by_default {

      sse_algorithm = "aws:kms"

      kms_master_key_id = aws_kms_key.ct.arn

    }

  }
}

resource "aws_s3_bucket_public_access_block" "logs" {
  bucket                  = aws_s3_bucket.logs.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_cloudwatch_log_group" "ct" {
  name              = var.cloudwatch_logs_group_name
  retention_in_days = var.cloudwatch_logs_retention_days
}

resource "aws_cloudtrail" "this" {
  name                          = var.name
  s3_bucket_name                = aws_s3_bucket.logs.bucket
  kms_key_id                    = aws_kms_key.ct.arn
  include_global_service_events = true
  is_multi_region_trail         = var.log_all_regions
  enable_log_file_validation    = var.enable_log_file_validation
  cloud_watch_logs_group_arn    = aws_cloudwatch_log_group.ct.arn
  cloud_watch_logs_role_arn     = aws_iam_role.ct.arn
}

resource "aws_iam_role" "ct" {
  name = "cloudtrail-to-cw"
  assume_role_policy = jsonencode({
    Version   = "2012-10-17",
    Statement = [{ Effect = "Allow", Principal = { Service = "cloudtrail.amazonaws.com" }, Action = "sts:AssumeRole" }]
  })
}

resource "aws_iam_role_policy" "ct" {
  role = aws_iam_role.ct.id
  policy = jsonencode({
    Version   = "2012-10-17",
    Statement = [{ Effect = "Allow", Action = ["logs:CreateLogStream", "logs:PutLogEvents"], Resource = "${aws_cloudwatch_log_group.ct.arn}:*" }]
  })
}

output "trail_arn" { value = aws_cloudtrail.this.arn }
output "bucket_name" { value = aws_s3_bucket.logs.bucket }
