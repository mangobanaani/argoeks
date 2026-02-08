# VPC Endpoints for MLOps Services
# SageMaker API, SageMaker Runtime, Bedrock Runtime

locals {
  endpoints = {
    sagemaker_api = {
      service_name = "com.amazonaws.${var.region}.sagemaker.api"
      type         = "Interface"
    }
    sagemaker_runtime = {
      service_name = "com.amazonaws.${var.region}.sagemaker.runtime"
      type         = "Interface"
    }
    bedrock_runtime = {
      service_name = "com.amazonaws.${var.region}.bedrock-runtime"
      type         = "Interface"
    }
  }
}

resource "aws_vpc_endpoint" "mlops" {
  for_each = local.endpoints

  vpc_id              = var.vpc_id
  service_name        = each.value.service_name
  vpc_endpoint_type   = each.value.type
  subnet_ids          = var.private_subnet_ids
  security_group_ids  = [aws_security_group.vpc_endpoints.id]
  private_dns_enabled = true

  tags = merge(
    var.tags,
    {
      Name = "${var.name_prefix}-${each.key}"
    }
  )
}

resource "aws_security_group" "vpc_endpoints" {
  name        = "${var.name_prefix}-mlops-vpc-endpoints"
  description      = "Security group for MLOps VPC endpoints"
  vpc_id           = var.vpc_id

  ingress {
    description = "HTTPS from VPC"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  egress {
    description = "All outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(
    var.tags,
    {
      Name = "${var.name_prefix}-mlops-vpc-endpoints"
    }
  )
}
