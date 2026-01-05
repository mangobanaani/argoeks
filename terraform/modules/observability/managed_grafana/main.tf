terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
  }
}

locals {
  name = "grafana-${var.environment}"
}

# Amazon Managed Grafana Workspace
resource "aws_grafana_workspace" "this" {
  count = var.enabled ? 1 : 0

  name                     = local.name
  account_access_type      = var.account_access_type
  authentication_providers = var.authentication_providers
  permission_type          = var.permission_type

  data_sources = var.data_sources

  notification_destinations = var.notification_destinations

  organization_role_name      = var.organization_role_name
  organizational_units        = var.organizational_units
  role_arn                    = var.role_arn != "" ? var.role_arn : null
  stack_set_name              = var.stack_set_name

  configuration = jsonencode({
    unifiedAlerting = {
      enabled = true
    }
    plugins = {
      pluginAdminEnabled = true
    }
  })

  tags = merge(
    var.tags,
    {
      Name        = local.name
      Environment = var.environment
    }
  )
}

# IAM role for Grafana to read from Prometheus
resource "aws_iam_role" "grafana" {
  count = var.enabled && var.create_iam_role ? 1 : 0
  name  = "${local.name}-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "grafana.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = var.tags
}

# Policy for Prometheus data source
resource "aws_iam_role_policy" "grafana_prometheus" {
  count = var.enabled && var.create_iam_role ? 1 : 0
  role  = aws_iam_role.grafana[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "aps:ListWorkspaces",
          "aps:DescribeWorkspace",
          "aps:QueryMetrics",
          "aps:GetLabels",
          "aps:GetSeries",
          "aps:GetMetricMetadata"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "ec2:DescribeInstances",
          "ec2:DescribeTags",
          "ec2:DescribeRegions"
        ]
        Resource = "*"
      }
    ]
  })
}

# Grafana API key for automation (optional)
resource "aws_grafana_workspace_api_key" "automation" {
  count = var.enabled && var.create_api_key ? 1 : 0

  key_name        = "automation-key"
  key_role        = "ADMIN"
  seconds_to_live = var.api_key_ttl
  workspace_id    = aws_grafana_workspace.this[0].id
}

# Store API key in Secrets Manager
resource "aws_secretsmanager_secret" "grafana_api_key" {
  count = var.enabled && var.create_api_key ? 1 : 0

  name_prefix = "${local.name}-api-key-"
  description = "API key for Grafana automation"

  tags = var.tags
}

resource "aws_secretsmanager_secret_version" "grafana_api_key" {
  count = var.enabled && var.create_api_key ? 1 : 0

  secret_id = aws_secretsmanager_secret.grafana_api_key[0].id
  secret_string = jsonencode({
    api_key    = aws_grafana_workspace_api_key.automation[0].key
    workspace_id = aws_grafana_workspace.this[0].id
    endpoint   = aws_grafana_workspace.this[0].endpoint
  })
}
