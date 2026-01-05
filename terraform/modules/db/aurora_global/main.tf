terraform {
  required_providers { aws = { source = "hashicorp/aws" } }
}

locals { db_port = var.engine == "aurora-mysql" ? 3306 : 5432 }

resource "aws_rds_global_cluster" "this" {
  global_cluster_identifier = var.name
  engine                    = var.engine
  engine_version            = var.engine_version
}

# Primary region resources use default provider
resource "aws_db_subnet_group" "primary" {
  name       = "${var.name}-p-subnets"
  subnet_ids = var.primary.subnet_ids
  tags       = var.tags
}

resource "aws_security_group" "primary" {
  name        = "${var.name}-p-sg"
  description = "Aurora Global primary"
  vpc_id      = var.primary.vpc_id
  ingress {
    from_port   = local.db_port
    to_port     = local.db_port
    protocol    = "tcp"
    cidr_blocks = [var.primary.vpc_cidr]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
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

resource "aws_rds_cluster" "primary" {
  cluster_identifier                  = "${var.name}-primary"
  engine                              = var.engine
  engine_version                      = var.engine_version
  database_name                       = var.database_name
  master_username                     = var.username
  master_password                     = random_password.master.result
  global_cluster_identifier           = aws_rds_global_cluster.this.id
  iam_database_authentication_enabled = true
  storage_encrypted                   = true
  kms_key_id                          = try(var.primary.kms_key_id, null)
  db_subnet_group_name                = aws_db_subnet_group.primary.name
  vpc_security_group_ids              = [aws_security_group.primary.id]
  backup_retention_period             = 7
  apply_immediately                   = false
  dynamic "serverlessv2_scaling_configuration" {
    for_each = try(var.primary.serverless_v2, true) ? [1] : []
    content {
      min_capacity = try(var.primary.min_acu, 2)
      max_capacity = try(var.primary.max_acu, 16)
    }
  }
  tags = var.tags
}

resource "aws_rds_cluster_instance" "primary" {
  count                        = try(var.primary.serverless_v2, true) ? 0 : try(var.primary.instances, 2)
  identifier                   = "${var.name}-p-${count.index}"
  cluster_identifier           = aws_rds_cluster.primary.id
  engine                       = var.engine
  engine_version               = var.engine_version
  instance_class               = try(var.primary.instance_class, "db.r6g.large")
  publicly_accessible          = false
  performance_insights_enabled = true
  apply_immediately            = false
  tags                         = var.tags
}

# Secondary region (use aliased provider "aws.secondary" from caller)
resource "aws_db_subnet_group" "secondary" {
  provider   = aws.secondary
  name       = "${var.name}-s-subnets"
  subnet_ids = var.secondary.subnet_ids
  tags       = var.tags
}

resource "aws_security_group" "secondary" {
  provider    = aws.secondary
  name        = "${var.name}-s-sg"
  description = "Aurora Global secondary"
  vpc_id      = var.secondary.vpc_id
  ingress {
    from_port   = local.db_port
    to_port     = local.db_port
    protocol    = "tcp"
    cidr_blocks = [var.secondary.vpc_cidr]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = var.tags
}

resource "aws_rds_cluster" "secondary" {
  provider                            = aws.secondary
  cluster_identifier                  = "${var.name}-secondary"
  engine                              = var.engine
  engine_version                      = var.engine_version
  global_cluster_identifier           = aws_rds_global_cluster.this.id
  iam_database_authentication_enabled = true
  storage_encrypted                   = true
  kms_key_id                          = try(var.secondary.kms_key_id, null)
  db_subnet_group_name                = aws_db_subnet_group.secondary.name
  vpc_security_group_ids              = [aws_security_group.secondary.id]
  backup_retention_period             = 7
  apply_immediately                   = false
  dynamic "serverlessv2_scaling_configuration" {
    for_each = try(var.secondary.serverless_v2, true) ? [1] : []
    content {
      min_capacity = try(var.secondary.min_acu, 2)
      max_capacity = try(var.secondary.max_acu, 16)
    }
  }
  tags = var.tags
}

resource "aws_rds_cluster_instance" "secondary" {
  provider                     = aws.secondary
  count                        = try(var.secondary.serverless_v2, true) ? 0 : try(var.secondary.instances, 2)
  identifier                   = "${var.name}-s-${count.index}"
  cluster_identifier           = aws_rds_cluster.secondary.id
  engine                       = var.engine
  engine_version               = var.engine_version
  instance_class               = try(var.secondary.instance_class, "db.r6g.large")
  publicly_accessible          = false
  performance_insights_enabled = true
  apply_immediately            = false
  tags                         = var.tags
}

