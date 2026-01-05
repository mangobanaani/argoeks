resource "aws_elasticache_subnet_group" "this" {
  name       = "${var.name}-subnets"
  subnet_ids = var.subnet_ids
}

resource "aws_security_group" "redis" {
  name        = "${var.name}-sg"
  description = "Redis access"
  vpc_id      = var.vpc_id

  ingress {
    from_port   = 6379
    to_port     = 6379
    protocol    = "tcp"
    cidr_blocks = concat([var.vpc_cidr], var.allowed_cidrs)
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

locals {
  use_existing_auth_secret = try(length(trimspace(var.existing_auth_secret_arn)) > 0, false)
}

resource "random_password" "auth" {
  count            = local.use_existing_auth_secret ? 0 : 1
  length           = 32
  special          = true
  override_special = "!-_=+" # Conservative set: only definitely safe characters
}

resource "random_id" "secret_suffix" {
  byte_length = 3
  keepers     = { name = var.name }
}

locals {
  generated_secret_name = local.use_existing_auth_secret ? null : coalesce(var.auth_token_secret_name, "${var.name}-auth-token-${random_id.secret_suffix.hex}")
}

data "aws_secretsmanager_secret" "existing_auth" {
  count = local.use_existing_auth_secret ? 1 : 0
  arn   = var.existing_auth_secret_arn
}

data "aws_secretsmanager_secret_version" "existing_auth" {
  count     = local.use_existing_auth_secret ? 1 : 0
  secret_id = data.aws_secretsmanager_secret.existing_auth[0].id
}

resource "aws_secretsmanager_secret" "auth" {
  count = local.use_existing_auth_secret ? 0 : 1
  name  = local.generated_secret_name
}

resource "aws_secretsmanager_secret_version" "auth" {
  count         = local.use_existing_auth_secret ? 0 : 1
  secret_id     = aws_secretsmanager_secret.auth[0].id
  secret_string = jsonencode({ auth_token = random_password.auth[0].result })
}

locals {
  auth_secret_arn  = local.use_existing_auth_secret ? var.existing_auth_secret_arn : aws_secretsmanager_secret.auth[0].arn
  auth_token_value = local.use_existing_auth_secret ? jsondecode(data.aws_secretsmanager_secret_version.existing_auth[0].secret_string)["auth_token"] : random_password.auth[0].result
}

resource "aws_elasticache_replication_group" "this" {
  replication_group_id       = var.name
  description                = "Redis for ${var.name}"
  engine                     = "redis"
  engine_version             = var.engine_version
  node_type                  = var.node_type
  parameter_group_name       = "default.redis7"
  subnet_group_name          = aws_elasticache_subnet_group.this.name
  security_group_ids         = [aws_security_group.redis.id]
  at_rest_encryption_enabled = true
  transit_encryption_enabled = true
  auth_token                 = local.auth_token_value
  automatic_failover_enabled = var.multi_az_enabled
  multi_az_enabled           = var.multi_az_enabled
  replicas_per_node_group    = var.replicas_per_node_group
}

output "primary_endpoint" { value = aws_elasticache_replication_group.this.primary_endpoint_address }
output "auth_token_secret_arn" { value = local.auth_secret_arn }
