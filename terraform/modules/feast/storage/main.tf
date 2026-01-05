resource "aws_dynamodb_table" "online" {
  name         = var.table_name
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "entity"
  range_key    = "feature"

  attribute {
    name = "entity"
    type = "S"
  }

  attribute {
    name = "feature"
    type = "S"
  }
}

resource "aws_s3_bucket" "offline" {
  bucket = var.bucket_name
}

resource "aws_s3_bucket_server_side_encryption_configuration" "offline" {
  count  = var.kms_key_arn != null ? 1 : 0
  bucket = aws_s3_bucket.offline.id
  rule {

    apply_server_side_encryption_by_default {

      sse_algorithm = "aws:kms"

      kms_master_key_id = var.kms_key_arn

    }

  }
}

output "table_arn" { value = aws_dynamodb_table.online.arn }
output "bucket_arn" { value = aws_s3_bucket.offline.arn }
