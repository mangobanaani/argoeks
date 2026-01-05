terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
    }
  }
}

resource "aws_iam_role" "this" {
  count = var.enabled ? 1 : 0
  name  = var.role_name
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "eks.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })
  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "cloudwatch" {
  count      = var.enabled ? 1 : 0
  role       = aws_iam_role.this[0].name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}

resource "aws_eks_addon" "this" {
  count                        = var.enabled ? 1 : 0
  cluster_name                 = var.cluster_name
  addon_name                   = "amazon-cloudwatch-observability"
  addon_version                = var.addon_version
  resolve_conflicts_on_create  = "OVERWRITE"
  resolve_conflicts_on_update  = "OVERWRITE"
  service_account_role_arn     = aws_iam_role.this[0].arn
  tags                         = var.tags
  depends_on                   = [aws_iam_role_policy_attachment.cloudwatch]
}
