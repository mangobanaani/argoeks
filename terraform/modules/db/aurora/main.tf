locals {
  db_port = var.engine == "aurora-mysql" ? 3306 : 5432
}

resource "aws_db_subnet_group" "this" {
  name       = "${var.name}-subnets"
  subnet_ids = var.subnet_ids
  tags       = var.tags
}

resource "aws_security_group" "db" {
  name        = "${var.name}-sg"
  description = "Aurora access"
  vpc_id      = var.vpc_id

  ingress {
    from_port   = local.db_port
    to_port     = local.db_port
    protocol    = "tcp"
    cidr_blocks = concat([var.vpc_cidr], var.allowed_cidrs)
  }
  dynamic "ingress" {
    for_each = var.allowed_sg_ids
    content {
      from_port       = local.db_port
      to_port         = local.db_port
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
  tags = var.tags
}

resource "random_password" "master" {
  length  = 24
  special = true
}

resource "aws_secretsmanager_secret" "db" {
  count = var.create_password_secret ? 1 : 0
  name  = coalesce(var.secret_name, "${var.name}-credentials")
  tags  = var.tags
}

resource "aws_secretsmanager_secret_version" "db" {
  count         = var.create_password_secret ? 1 : 0
  secret_id     = aws_secretsmanager_secret.db[0].id
  secret_string = jsonencode({ username = var.username, password = random_password.master.result, engine = var.engine, dbname = var.database_name })
}

resource "aws_rds_cluster" "this" {
  cluster_identifier                  = var.name
  engine                              = var.engine
  engine_version                      = var.engine_version
  database_name                       = var.database_name
  master_username                     = var.username
  master_password                     = random_password.master.result
  iam_database_authentication_enabled = var.enable_iam_auth

  storage_encrypted = true
  kms_key_id        = var.kms_key_id

  db_subnet_group_name   = aws_db_subnet_group.this.name
  vpc_security_group_ids = [aws_security_group.db.id]

  deletion_protection          = var.deletion_protection
  backup_retention_period      = var.backup_retention_days
  preferred_backup_window      = var.preferred_backup_window
  preferred_maintenance_window = var.preferred_maintenance_window
  apply_immediately            = var.apply_immediately

  dynamic "serverlessv2_scaling_configuration" {
    for_each = var.serverless_v2 ? [1] : []
    content {
      min_capacity = var.min_acu
      max_capacity = var.max_acu
    }
  }

  tags = var.tags
}

resource "aws_rds_cluster_instance" "this" {
  count                        = var.instances
  identifier                   = "${var.name}-${count.index}"
  cluster_identifier           = aws_rds_cluster.this.id
  engine                       = var.engine
  engine_version               = var.engine_version
  instance_class               = var.serverless_v2 ? "db.serverless" : var.instance_class
  publicly_accessible          = false
  monitoring_interval          = var.monitoring_interval
  performance_insights_enabled = var.performance_insights
  apply_immediately            = var.apply_immediately
  tags                         = var.tags
}

