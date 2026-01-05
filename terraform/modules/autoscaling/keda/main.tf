terraform {
  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">= 2.20"
    }
    helm = {
      source  = "hashicorp/helm"
      version = ">= 2.10"
    }
  }
}

locals {
  namespace = var.namespace

  # KEDA configuration values
  keda_values = {
    # Resource limits for KEDA operator
    resources = {
      limits = {
        cpu    = var.operator_resources.limits_cpu
        memory = var.operator_resources.limits_memory
      }
      requests = {
        cpu    = var.operator_resources.requests_cpu
        memory = var.operator_resources.requests_memory
      }
    }

    # Metrics server resource limits
    metricsServer = {
      resources = {
        limits = {
          cpu    = var.metrics_server_resources.limits_cpu
          memory = var.metrics_server_resources.limits_memory
        }
        requests = {
          cpu    = var.metrics_server_resources.requests_cpu
          memory = var.metrics_server_resources.requests_memory
        }
      }
    }

    # Service account for IRSA
    serviceAccount = {
      create = var.create_service_account
      name   = var.service_account_name
      annotations = var.enable_irsa ? {
        "eks.amazonaws.com/role-arn" = aws_iam_role.keda[0].arn
      } : {}
    }

    # Prometheus integration
    prometheus = {
      operator = {
        enabled = var.enable_prometheus_servicemonitor
      }
    }

    # Pod security
    podSecurityContext = {
      fsGroup      = 1000
      runAsNonRoot = true
      runAsUser    = 1000
    }

    # High availability
    replicaCount = var.replicas

    # Pod disruption budget
    podDisruptionBudget = {
      enabled        = var.enable_pdb
      minAvailable   = var.pdb_min_available
    }
  }
}

# Namespace for KEDA
resource "kubernetes_namespace_v1" "keda" {
  count = var.create_namespace ? 1 : 0

  metadata {
    name = local.namespace
    labels = {
      name                                      = local.namespace
      "pod-security.kubernetes.io/enforce"      = "baseline"
      "pod-security.kubernetes.io/audit"        = "baseline"
      "pod-security.kubernetes.io/warn"         = "baseline"
    }
  }
}

# IAM role for KEDA (for accessing AWS services like SQS, CloudWatch)
resource "aws_iam_role" "keda" {
  count = var.enable_irsa ? 1 : 0

  name_prefix = "${var.cluster_name}-keda-"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Federated = var.oidc_provider_arn
      }
      Action = "sts:AssumeRoleWithWebIdentity"
      Condition = {
        StringEquals = {
          "${var.oidc_issuer_url}:sub" = "system:serviceaccount:${local.namespace}:${var.service_account_name}"
          "${var.oidc_issuer_url}:aud" = "sts.amazonaws.com"
        }
      }
    }]
  })

  tags = var.tags
}

# IAM policy for KEDA to access AWS services
resource "aws_iam_role_policy" "keda_permissions" {
  count = var.enable_irsa ? 1 : 0

  role = aws_iam_role.keda[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "sqs:GetQueueAttributes",
          "sqs:GetQueueUrl"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "cloudwatch:GetMetricData",
          "cloudwatch:GetMetricStatistics",
          "cloudwatch:ListMetrics"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "dynamodb:DescribeTable",
          "dynamodb:DescribeStream"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "kinesis:DescribeStream",
          "kinesis:DescribeStreamSummary",
          "kinesis:GetRecords",
          "kinesis:GetShardIterator"
        ]
        Resource = "*"
      }
    ]
  })
}

# KEDA Helm chart installation
resource "helm_release" "keda" {
  count = var.install ? 1 : 0

  name       = "keda"
  repository = "https://kedacore.github.io/charts"
  chart      = "keda"
  version    = var.keda_version
  namespace  = local.namespace

  timeout         = 600
  wait            = true
  wait_for_jobs   = true
  cleanup_on_fail = true

  values = [yamlencode(local.keda_values)]

  depends_on = [
    kubernetes_namespace_v1.keda,
    aws_iam_role_policy.keda_permissions
  ]
}
