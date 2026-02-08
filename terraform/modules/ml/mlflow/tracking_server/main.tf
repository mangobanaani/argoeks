# MLflow Tracking Server Infrastructure
# RDS Postgres for metadata, S3 for artifacts

locals {
  db_name     = "mlflow"
  db_username = "mlflow"
}

# S3 bucket for MLflow artifacts
resource "aws_s3_bucket" "artifacts" {
  bucket = "${var.name_prefix}-mlflow-artifacts-${data.aws_caller_identity.current.account_id}"

  tags = merge(
    var.tags,
    {
      Name    = "${var.name_prefix}-mlflow-artifacts"
      Purpose = "MLflow Artifacts Storage"
    }
  )
}

resource "aws_s3_bucket_server_side_encryption_configuration" "artifacts" {
  bucket = aws_s3_bucket.artifacts.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = var.kms_key_arn
    }
    bucket_key_enabled = true
  }
}

resource "aws_s3_bucket_public_access_block" "artifacts" {
  bucket = aws_s3_bucket.artifacts.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_versioning" "artifacts" {
  bucket = aws_s3_bucket.artifacts.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "artifacts" {
  bucket = aws_s3_bucket.artifacts.id

  rule {
    id     = "transition-old-artifacts"
    status = "Enabled"

    transition {
      days          = 180  # 6 months
      storage_class = "INTELLIGENT_TIERING"
    }

    transition {
      days          = 365  # 1 year
      storage_class = "GLACIER_IR"
    }
  }

  rule {
    id     = "expire-very-old-artifacts"
    status = "Enabled"

    expiration {
      days = 730  # 2 years retention for ML artifacts
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

# RDS Postgres for MLflow metadata
resource "aws_db_subnet_group" "mlflow" {
  name       = "${var.name_prefix}-mlflow-db"
  subnet_ids = var.subnet_ids

  tags = merge(
    var.tags,
    {
      Name = "${var.name_prefix}-mlflow-db"
    }
  )
}

resource "aws_security_group" "mlflow_db" {
  name_prefix = "${var.name_prefix}-mlflow-db-"
  description = "Security group for MLflow RDS database"
  vpc_id      = var.vpc_id

  ingress {
    description = "PostgreSQL from VPC"
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  egress {
    description = "Allow outbound to VPC"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = [var.vpc_cidr]
  }

  tags = merge(
    var.tags,
    {
      Name = "${var.name_prefix}-mlflow-db"
    }
  )
}

resource "random_password" "mlflow_db" {
  length  = 32
  special = true
}

resource "aws_secretsmanager_secret" "mlflow_db" {
  name_prefix = "${var.name_prefix}-mlflow-db-"
  description = "MLflow database credentials"

  tags = var.tags
}

resource "aws_secretsmanager_secret_version" "mlflow_db" {
  secret_id = aws_secretsmanager_secret.mlflow_db.id
  secret_string = jsonencode({
    username = local.db_username
    password = random_password.mlflow_db.result
    host     = aws_db_instance.mlflow.address
    port     = aws_db_instance.mlflow.port
    dbname   = local.db_name
    engine   = "postgres"
  })
}

resource "aws_db_instance" "mlflow" {
  identifier     = "${var.name_prefix}-mlflow"
  engine         = "postgres"
  engine_version = var.postgres_version
  instance_class = var.rds_instance_class

  allocated_storage     = var.storage_gb
  max_allocated_storage = var.storage_gb * 2
  storage_type          = "gp3"
  storage_encrypted     = true
  kms_key_id            = var.kms_key_arn

  db_name  = local.db_name
  username = local.db_username
  password = random_password.mlflow_db.result

  db_subnet_group_name   = aws_db_subnet_group.mlflow.name
  vpc_security_group_ids = [aws_security_group.mlflow_db.id]

  multi_az                  = var.multi_az
  publicly_accessible       = false
  skip_final_snapshot       = var.skip_final_snapshot
  final_snapshot_identifier = var.skip_final_snapshot ? null : "${var.name_prefix}-mlflow-final-${formatdate("YYYY-MM-DD-hhmm", timestamp())}"

  backup_retention_period = var.backup_retention_days
  backup_window           = "03:00-04:00"
  maintenance_window      = "mon:04:00-mon:05:00"

  enabled_cloudwatch_logs_exports = ["postgresql", "upgrade"]

  deletion_protection = var.deletion_protection

  tags = merge(
    var.tags,
    {
      Name    = "${var.name_prefix}-mlflow"
      Purpose = "MLflow Tracking Server Database"
    }
  )
}

data "aws_caller_identity" "current" {}
