terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
    }
    kubernetes = {
      source = "hashicorp/kubernetes"
    }
    helm = {
      source = "hashicorp/helm"
    }
  }
}

data "aws_caller_identity" "current" {}

locals {
  issuer_hostpath              = replace(var.oidc_issuer_url, "https://", "")
  controller_policy_document   = var.controller_policy_json != "" ? var.controller_policy_json : file("${path.module}/controller-policy.json")
}

resource "kubernetes_namespace_v1" "ns" {
  count = var.install ? 1 : 0
  metadata { name = var.namespace }
}

# Controller IRSA
data "aws_iam_policy_document" "assume" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    principals {

      type = "Federated"

      identifiers = ["arn:aws:iam::${data.aws_caller_identity.current.account_id}:oidc-provider/${local.issuer_hostpath}"]

    }
    condition {
      test     = "StringEquals"
      variable = "${local.issuer_hostpath}:sub"
      values   = ["system:serviceaccount:${var.namespace}:karpenter"]
    }
  }
}

resource "aws_iam_role" "controller" {
  name               = "${var.cluster_name}-karpenter-controller"
  assume_role_policy = data.aws_iam_policy_document.assume.json
  tags               = var.tags
}

resource "aws_iam_policy" "controller_managed" {
  name   = "${var.cluster_name}-karpenter-controller-policy"
  policy = local.controller_policy_document
}

resource "aws_iam_role_policy_attachment" "controller_managed" {
  role       = aws_iam_role.controller.name
  policy_arn = aws_iam_policy.controller_managed.arn
}

# Node role + instance profile
resource "aws_iam_role" "node" {
  name = coalesce(var.node_role_name, "${var.cluster_name}-karpenter-node")
  assume_role_policy = jsonencode({
    Version   = "2012-10-17",
    Statement = [{ Effect = "Allow", Principal = { Service = "ec2.amazonaws.com" }, Action = "sts:AssumeRole" }]
  })
  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "node_eks" {
  role       = aws_iam_role.node.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
}
resource "aws_iam_role_policy_attachment" "node_cni" {
  role       = aws_iam_role.node.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
}
resource "aws_iam_role_policy_attachment" "node_ecr" {
  role       = aws_iam_role.node.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}
resource "aws_iam_role_policy_attachment" "node_ssm" {
  role       = aws_iam_role.node.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "node" {
  name = "${aws_iam_role.node.name}-profile"
  role = aws_iam_role.node.name
}

# Allow controller to pass the node role
resource "aws_iam_policy" "passrole" {
  name = "${var.cluster_name}-karpenter-passrole"
  policy = jsonencode({
    Version   = "2012-10-17",
    Statement = [{ Effect = "Allow", Action = ["iam:PassRole"], Resource = aws_iam_role.node.arn }]
  })
}
resource "aws_iam_role_policy_attachment" "controller_passrole" {
  role       = aws_iam_role.controller.name
  policy_arn = aws_iam_policy.passrole.arn
}

resource "helm_release" "karpenter" {
  count      = var.install ? 1 : 0
  name       = "karpenter"
  namespace  = var.namespace
  repository = "oci://public.ecr.aws/karpenter"
  chart      = "karpenter"
  version    = var.karpenter_chart_version
  wait       = true
  timeout    = 300
  values = [yamlencode({
    replicas = 2
    serviceAccount = {
      create      = true
      name        = "karpenter"
      annotations = { "eks.amazonaws.com/role-arn" = aws_iam_role.controller.arn }
    }
    settings = {
      clusterName     = var.cluster_name
      clusterEndpoint = var.cluster_endpoint
      interruptionQueue = "${var.cluster_name}-karpenter"
    }
    controller = {
      resources = {
        requests = {
          cpu    = "200m"
          memory = "256Mi"
        }
        limits = {
          cpu    = "1000m"
          memory = "1Gi"
        }
      }
    }
  })]
  depends_on = [kubernetes_namespace_v1.ns]
}

# Default NodeClass/NodePool (Karpenter v1 APIs)
# Note: Disabled for single-stage deployment - managed via GitOps
resource "kubernetes_manifest" "nodeclass" {
  count = 0
  manifest = {
    apiVersion = "karpenter.k8s.aws/v1"
    kind       = "EC2NodeClass"
    metadata   = { name = "${var.default_nodepool_name}" }
    spec = {
      amiSelectorTerms = [
        { alias = "al2023@latest" }
      ]
      role                       = aws_iam_role.node.name
      subnetSelectorTerms        = [{ tags = { "karpenter.sh/discovery" = var.cluster_name } }]
      securityGroupSelectorTerms = [{ tags = { "karpenter.sh/discovery" = var.cluster_name } }]
      metadataOptions = {
        httpEndpoint            = "enabled"
        httpProtocolIPv6        = "disabled"
        httpPutResponseHopLimit = 2
        httpTokens              = "required"
      }
      tags = var.tags
    }
  }
  depends_on = [helm_release.karpenter]
}

# Note: Disabled for single-stage deployment - managed via GitOps
resource "kubernetes_manifest" "nodepool" {
  count = 0
  manifest = {
    apiVersion = "karpenter.sh/v1"
    kind       = "NodePool"
    metadata   = { name = var.default_nodepool_name }
    spec = {
      template = {
        spec = {
          nodeClassRef = {
            group = "karpenter.k8s.aws"
            kind  = "EC2NodeClass"
            name  = kubernetes_manifest.nodeclass[0].manifest.metadata.name
          }
          requirements = [
            { key = "kubernetes.io/arch", operator = "In", values = var.default_instance_arch },
            { key = "karpenter.sh/capacity-type", operator = "In", values = var.default_capacity_type }
          ]
          taints = [for t in var.default_taints : { key = t.key, value = try(t.value, null), effect = t.effect }]
        }
      }
      disruption = {
        consolidationPolicy = "WhenEmptyOrUnderutilized"
        consolidateAfter = "5m"
      }
      limits = { cpu = "2000" }
    }
  }
  depends_on = [kubernetes_manifest.nodeclass]
}

output "controller_role_arn" { value = aws_iam_role.controller.arn }
output "node_role_name" { value = aws_iam_role.node.name }
output "instance_profile_name" { value = aws_iam_instance_profile.node.name }
