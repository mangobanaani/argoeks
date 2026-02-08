resource "aws_db_subnet_group" "this" {
  name       = "${var.name}-subnets"
  subnet_ids = var.subnet_ids
}

resource "aws_db_parameter_group" "this" {
  name        = "${var.name}-pg"
  family      = "postgres16"
  description = "Parameter group for ${var.name}"
  dynamic "parameter" {
    for_each = var.require_ssl ? [1] : []
    content {
      name  = "rds.force_ssl"
      value = "1"
    }
  }
}

resource "aws_security_group" "db" {
  name        = "${var.name}-sg"
  description = "RDS Postgres access"
  vpc_id      = var.vpc_id

  ingress {
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = concat([var.vpc_cidr], var.allowed_cidrs)
  }

  dynamic "ingress" {
    for_each = var.allowed_sg_ids
    content {
      from_port       = 5432
      to_port         = 5432
      protocol        = "tcp"
      security_groups = [ingress.value]
    }
  }

  egress {
    description = "Allow outbound to VPC"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = concat([var.vpc_cidr], var.allowed_cidrs)
  }
}

locals {
  use_existing_db_secret = try(length(trimspace(var.existing_secret_arn)) > 0, false)
}

resource "random_password" "db" {
  length           = 20
  special          = true
  override_special = "!#$%^&*()-_=+[]{}?:.,"
}

resource "random_id" "secret_suffix" {
  byte_length = 3
  keepers     = { name = var.name }
}

locals {
  secret_name_effective = coalesce(var.secret_name, "${var.name}-credentials-${random_id.secret_suffix.hex}")
}

data "aws_secretsmanager_secret" "existing_db" {
  count = local.use_existing_db_secret ? 1 : 0
  arn   = var.existing_secret_arn
}

data "aws_secretsmanager_secret_version" "existing_db" {
  count     = local.use_existing_db_secret ? 1 : 0
  secret_id = data.aws_secretsmanager_secret.existing_db[0].id
}

resource "aws_secretsmanager_secret" "db" {
  count = local.use_existing_db_secret || !var.create_password_secret ? 0 : 1
  name  = local.secret_name_effective
}

resource "aws_secretsmanager_secret_version" "db" {
  count         = local.use_existing_db_secret || !var.create_password_secret ? 0 : 1
  secret_id     = aws_secretsmanager_secret.db[0].id
  secret_string = jsonencode({ username = var.username, password = random_password.db.result, engine = "postgres", dbname = var.db_name })
}

locals {
  db_credentials = local.use_existing_db_secret ? jsondecode(data.aws_secretsmanager_secret_version.existing_db[0].secret_string) : {
    username = var.username
    password = random_password.db.result
  }
  db_password_value = local.db_credentials.password
  db_secret_arn     = local.use_existing_db_secret ? var.existing_secret_arn : (var.create_password_secret ? aws_secretsmanager_secret.db[0].arn : null)
}

resource "aws_db_instance" "this" {
  identifier                          = var.name
  engine                              = "postgres"
  engine_version                      = var.engine_version
  instance_class                      = var.instance_class
  db_name                             = var.db_name
  username                            = var.username
  password                            = local.db_password_value
  allocated_storage                   = var.allocated_storage
  max_allocated_storage               = var.max_allocated_storage
  multi_az                            = var.multi_az
  db_subnet_group_name                = aws_db_subnet_group.this.name
  vpc_security_group_ids              = [aws_security_group.db.id]
  storage_encrypted                   = true
  kms_key_id                          = var.kms_key_id
  deletion_protection                 = var.deletion_protection
  skip_final_snapshot                 = var.skip_final_snapshot
  backup_retention_period             = var.backup_retention_days
  performance_insights_enabled        = var.performance_insights
  apply_immediately                   = false
  publicly_accessible                 = false
  auto_minor_version_upgrade          = true
  copy_tags_to_snapshot               = true
  enabled_cloudwatch_logs_exports     = ["postgresql", "upgrade"]
  parameter_group_name                = aws_db_parameter_group.this.name
  iam_database_authentication_enabled = var.enable_iam_auth
}

output "endpoint" { value = aws_db_instance.this.address }
output "port" { value = aws_db_instance.this.port }
output "secret_arn" { value = local.db_secret_arn }
output "security_group_id" { value = aws_security_group.db.id }
output "resource_id" { value = aws_db_instance.this.resource_id }
output "db_instance_identifier" { value = aws_db_instance.this.id }

output "iam_connect_policy_json" {
  value = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect   = "Allow",
      Action   = "rds-db:connect",
      Resource = "arn:aws:rds-db:${data.aws_region.current.id}:${data.aws_caller_identity.current.account_id}:dbuser:${aws_db_instance.this.resource_id}/${var.username}"
    }]
  })
}

data "aws_region" "current" {}
data "aws_caller_identity" "current" {}
