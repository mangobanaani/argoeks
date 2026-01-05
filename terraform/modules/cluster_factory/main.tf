data "aws_caller_identity" "terraform" {}

locals {
  # Standard cost allocation and compliance tags
  standard_tags = merge(
    {
      # Cost Allocation
      CostCenter   = var.cost_center
      Project      = var.project
      Environment  = var.environment
      Owner        = var.owner
      Application  = "argoeks"
      ManagedBy    = "Terraform"

      # Technical
      TerraformWorkspace = terraform.workspace
      TerraformModule    = "cluster_factory"

      # Compliance
      Compliance       = var.compliance_requirements
      DataClassification = var.data_classification
      BackupPolicy     = var.backup_policy
    },
    var.additional_tags
  )

  # Create numbered cluster names, first is management cluster (hub)
  cluster_names = [for i in range(var.cluster_count) : format("%s-cluster-%02d", var.name_prefix, i + 1)]

  # Simple size presets
  size_map = {
    small  = { node_type = "t3.large", desired = 2 }   # Dev: 2 vCPU, 8GB RAM, 2 nodes
    medium = { node_type = "m5.xlarge", desired = 3 }  # Staging: 4 vCPU, 16GB RAM
    large  = { node_type = "m5.2xlarge", desired = 4 } # Prod: 8 vCPU, 32GB RAM
    xlarge = { node_type = "m5.4xlarge", desired = 6 } # Enterprise: 16 vCPU, 64GB RAM
  }

  node_defaults = lookup(local.size_map, var.cluster_config.size, local.size_map["medium"])

  # Smart Cilium enablement - auto-disable if Fargate is enabled
  # Fargate doesn't support custom CNI plugins or DaemonSets
  cilium_enabled = var.enable_cilium && !var.enable_fargate

  # Fargate profile configuration
  fargate_enabled = var.enable_fargate || length(var.fargate_profiles) > 0

  # Default Fargate profiles for serverless namespaces
  default_fargate_profiles = var.enable_fargate ? {
    for ns in var.fargate_profile_defaults.namespaces : ns => {
      name = "fargate-${ns}"
      selectors = [{
        namespace = ns
        labels    = {}
      }]
      subnet_ids = []
      tags       = {}
    }
  } : {}

  # Merge custom + default Fargate profiles
  all_fargate_profiles = merge(local.default_fargate_profiles, var.fargate_profiles)

  clusters = {
    for name in local.cluster_names : name => {
      name = name
      labels = merge(local.standard_tags, {
        # Cluster-specific labels
        cluster_type = var.cluster_config.type
        tenancy      = var.cluster_config.tenancy
        compliance   = var.cluster_config.compliance
        hub          = name == local.cluster_names[0] ? "true" : "false"
        environment  = var.environment
        cni          = local.cilium_enabled ? "cilium" : "aws-vpc-cni"
        fargate      = local.fargate_enabled ? "enabled" : "disabled"

        # EKS-specific tags
        "kubernetes.io/cluster/${name}" = "owned"
        "karpenter.sh/discovery"        = name
      })
      k8s_version = var.cluster_config.version
      nodes       = local.node_defaults
      az_count    = 3
      # Derive non-overlapping /16 CIDRs per cluster from base_cidr
      cidr = cidrsubnet(var.base_cidr, 8, index(local.cluster_names, name)) # 10.<idx>.0.0/16
    }
  }

  # BYOCNI: Default addons removed - only CoreDNS configured in cluster_addons

  managed_addon_specs = {
    "amazon-cloudwatch-observability" = {
      enabled     = var.enable_cloudwatch_observability
      addon_name  = "amazon-cloudwatch-observability"
      most_recent = true
      service_accounts = [{
        namespace = "amazon-cloudwatch"
        name      = "cloudwatch-agent"
        policies = [
          "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy",
          "arn:aws:iam::aws:policy/AWSXrayWriteOnlyAccess",
        ]
        iam_mode = "irsa"
      }]
      tags = {}
    }
    "aws-guardduty-agent" = {
      enabled     = var.enable_guardduty_runtime
      addon_name  = "aws-guardduty-agent"
      most_recent = true
      tags        = {}
    }
    "aws-network-flow-monitoring-agent" = {
      enabled     = var.enable_network_flow_monitor
      addon_name  = "aws-network-flow-monitoring-agent"
      most_recent = true
      service_accounts = [{
        namespace = "amazon-network-flow-monitor"
        name      = "aws-network-flow-monitor-agent-service-account"
        policies  = ["arn:aws:iam::aws:policy/CloudWatchNetworkFlowMonitorAgentPublishPolicy"]
        iam_mode  = "irsa"
      }]
      tags = {}
    }
    "eks-node-monitoring-agent" = {
      enabled     = var.enable_node_monitoring_agent
      addon_name  = "eks-node-monitoring-agent"
      most_recent = true
      tags        = {}
    }
    "eks-pod-identity-agent" = {
      enabled        = var.enable_pod_identity_agent
      addon_name     = "eks-pod-identity-agent"
      most_recent    = true
      before_compute = true
      tags           = {}
    }
    "aws-secrets-store-csi-driver-provider" = {
      enabled     = var.enable_secrets_store_provider
      addon_name  = "aws-secrets-store-csi-driver-provider"
      most_recent = true
      tags        = {}
    }
    "amazon-sagemaker-hyperpod-observability" = {
      enabled     = var.enable_hyperpod_observability
      addon_name  = "amazon-sagemaker-hyperpod-observability"
      most_recent = true
      service_accounts = [{
        namespace = "hyperpod-observability"
        name      = "hyperpod-observability-operator-otel-collector"
        policies = [
          "arn:aws:iam::aws:policy/AmazonPrometheusRemoteWriteAccess",
          "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy",
        ]
        iam_mode = "irsa"
      }]
      tags = {}
    }
    "amazon-sagemaker-hyperpod-taskgovernance" = {
      enabled     = var.enable_hyperpod_task_governance
      addon_name  = "amazon-sagemaker-hyperpod-taskgovernance"
      most_recent = true
      tags        = {}
    }
    "amazon-sagemaker-hyperpod-training-operator" = {
      enabled     = var.enable_hyperpod_training_operator
      addon_name  = "amazon-sagemaker-hyperpod-training-operator"
      most_recent = true
      service_accounts = [{
        namespace = "aws-hyperpod"
        name      = "hp-training-operator-controller-manager"
        policies  = ["arn:aws:iam::aws:policy/AmazonSageMakerHyperPodTrainingOperatorAccess"]
        iam_mode  = "irsa"
      }]
      tags = {}
    }
    "amazon-sagemaker-spaces" = {
      enabled     = var.enable_sagemaker_spaces
      addon_name  = "amazon-sagemaker-spaces"
      most_recent = true
      service_accounts = [
        {
          namespace = "jupyter-k8s-system"
          name      = "jupyter-k8s-controller-manager"
          policies  = ["arn:aws:iam::aws:policy/AmazonSageMakerSpacesControllerPolicy"]
          iam_mode  = "pod_identity"
        },
        {
          namespace = "jupyter-k8s-system"
          name      = "jupyter-k8s-authmiddleware"
          policies  = ["arn:aws:iam::aws:policy/AmazonSageMakerSpacesRouterPolicy"]
          iam_mode  = "pod_identity"
        }
      ]
      tags = {}
    }
  }

  managed_addon_names  = concat(["aws-ebs-csi-driver"], keys(local.managed_addon_specs))
  ebs_csi_addon_config = try(var.cluster_addons["aws-ebs-csi-driver"], {})
  ebs_csi_service_account = "system:serviceaccount:kube-system:ebs-csi-controller-sa"

  enabled_managed_addons = {
    for addon_key, spec in local.managed_addon_specs : addon_key => spec if try(spec.enabled, false)
  }

  managed_addon_instances = {
    for combo in flatten([
      for cluster_key, cluster in local.clusters : [
        for addon_key, spec in local.enabled_managed_addons : {
          key         = "${cluster_key}|${addon_key}"
          cluster_key = cluster_key
          addon_name  = addon_key
          spec        = spec
        }
      ]
      ]) : combo.key => {
      cluster_key = combo.cluster_key
      addon_name  = combo.addon_name
      spec        = combo.spec
    }
  }

  managed_addon_role_specs = {
    for role_combo in flatten([
      for instance_key, instance in local.managed_addon_instances : [
        for sa in try(instance.spec.service_accounts, []) : {
          instance_key    = instance_key
          cluster_key     = instance.cluster_key
          addon_name      = instance.addon_name
          service_account = sa.name
          namespace       = sa.namespace
          policies        = try(sa.policies, [])
          iam_mode        = try(sa.iam_mode, "irsa")
        }
      ]
      ]) : "${role_combo.instance_key}|${role_combo.service_account}" => {
      cluster_key     = role_combo.cluster_key
      addon_name      = role_combo.addon_name
      service_account = role_combo.service_account
      namespace       = role_combo.namespace
      policies        = role_combo.policies
      iam_mode        = role_combo.iam_mode
    }
    if length(role_combo.policies) > 0
  }

  managed_addon_pod_identity_specs = {
    for k, spec in local.managed_addon_role_specs : k => spec if spec.iam_mode == "pod_identity"
  }

  addon_role_keys_by_instance = {
    for instance_key, instance in local.managed_addon_instances :
    instance_key => [
      for role_key, spec in local.managed_addon_role_specs :
      role_key
      if spec.cluster_key == instance.cluster_key && spec.addon_name == instance.addon_name
    ]
  }

  managed_addon_role_policy_keys = {
    for policy_combo in flatten([
      for role_key, spec in local.managed_addon_role_specs : [
        for policy_arn in spec.policies : {
          role_key   = role_key
          policy_arn = policy_arn
        }
      ]
      ]) : "${policy_combo.role_key}|${policy_combo.policy_arn}" => {
      role_key   = policy_combo.role_key
      policy_arn = policy_combo.policy_arn
    }
  }

  # Short IAM role names (≤38 chars) using deterministic hash
  managed_addon_role_names = {
    for k, spec in local.managed_addon_role_specs :
    k => substr("${spec.cluster_key}-${substr(md5("${spec.addon_name}-${spec.service_account}"), 0, 8)}-", 0, 38)
  }
}

# Validation: Warn if Cilium was requested but Fargate is enabled
resource "null_resource" "cilium_fargate_warning" {
  count = var.enable_cilium && var.enable_fargate ? 1 : 0

  provisioner "local-exec" {
    command = <<-EOT
      echo "WARNING: Cilium and Fargate are incompatible."
      echo "   Cilium requires DaemonSets and custom CNI, which Fargate doesn't support."
      echo "   Cilium has been automatically DISABLED for this cluster."
      echo "   Using AWS VPC CNI for all pods (including Fargate)."
      echo ""
      echo "   Options:"
      echo "   1. Use EC2 nodes only with Cilium (set enable_fargate=false)"
      echo "   2. Use Fargate only without Cilium (set enable_cilium=false)"
      echo "   3. Use hybrid: EC2 nodes + Fargate with AWS VPC CNI (current)"
    EOT
  }
}

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "6.5.1"

  for_each = local.clusters

  name = "${each.value.name}-vpc"
  cidr = each.value.cidr

  azs             = [for z in range(each.value.az_count) : "${var.region}${substr("abc", z, 1)}"]
  private_subnets = [for n in range(each.value.az_count) : cidrsubnet(each.value.cidr, 4, n)]
  public_subnets  = [for n in range(each.value.az_count) : cidrsubnet(each.value.cidr, 4, n + 8)]

  enable_nat_gateway  = true
  single_nat_gateway  = true
  public_subnet_tags  = { "kubernetes.io/role/elb" = 1, "karpenter.sh/discovery" = each.value.name }
  private_subnet_tags = { "kubernetes.io/role/internal-elb" = 1, "karpenter.sh/discovery" = each.value.name }
  tags                = each.value.labels
}

# Security group for Interface VPC Endpoints
resource "aws_security_group" "vpce" {
  for_each    = var.enable_vpc_endpoints ? local.clusters : {}
  name        = "${each.value.name}-vpce"
  description = "Interface VPC Endpoints"
  vpc_id      = module.vpc[each.key].vpc_id

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [each.value.cidr]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = [each.value.cidr]
  }
  tags = merge(each.value.labels, { purpose = "vpc-endpoints" })
}

# Gateway endpoint for S3
resource "aws_vpc_endpoint" "s3" {
  for_each          = var.enable_vpc_endpoints ? local.clusters : {}
  vpc_id            = module.vpc[each.key].vpc_id
  service_name      = "com.amazonaws.${var.region}.s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = module.vpc[each.key].private_route_table_ids
  tags              = each.value.labels
}

# Create one resource per interface service to avoid limitations of for_each in a single resource
resource "aws_vpc_endpoint" "ecr_api" {
  for_each            = var.enable_vpc_endpoints ? local.clusters : {}
  vpc_id              = module.vpc[each.key].vpc_id
  service_name        = "com.amazonaws.${var.region}.ecr.api"
  vpc_endpoint_type   = "Interface"
  private_dns_enabled = true
  subnet_ids          = module.vpc[each.key].private_subnets
  security_group_ids  = [aws_security_group.vpce[each.key].id]
  tags                = each.value.labels
}

resource "aws_vpc_endpoint" "ecr_dkr" {
  for_each            = var.enable_vpc_endpoints ? local.clusters : {}
  vpc_id              = module.vpc[each.key].vpc_id
  service_name        = "com.amazonaws.${var.region}.ecr.dkr"
  vpc_endpoint_type   = "Interface"
  private_dns_enabled = true
  subnet_ids          = module.vpc[each.key].private_subnets
  security_group_ids  = [aws_security_group.vpce[each.key].id]
  tags                = each.value.labels
}

resource "aws_vpc_endpoint" "sts" {
  for_each            = var.enable_vpc_endpoints ? local.clusters : {}
  vpc_id              = module.vpc[each.key].vpc_id
  service_name        = "com.amazonaws.${var.region}.sts"
  vpc_endpoint_type   = "Interface"
  private_dns_enabled = true
  subnet_ids          = module.vpc[each.key].private_subnets
  security_group_ids  = [aws_security_group.vpce[each.key].id]
  tags                = each.value.labels
}

resource "aws_vpc_endpoint" "logs" {
  for_each            = var.enable_vpc_endpoints ? local.clusters : {}
  vpc_id              = module.vpc[each.key].vpc_id
  service_name        = "com.amazonaws.${var.region}.logs"
  vpc_endpoint_type   = "Interface"
  private_dns_enabled = true
  subnet_ids          = module.vpc[each.key].private_subnets
  security_group_ids  = [aws_security_group.vpce[each.key].id]
  tags                = each.value.labels
}

resource "aws_vpc_endpoint" "ec2" {
  for_each            = var.enable_vpc_endpoints ? local.clusters : {}
  vpc_id              = module.vpc[each.key].vpc_id
  service_name        = "com.amazonaws.${var.region}.ec2"
  vpc_endpoint_type   = "Interface"
  private_dns_enabled = true
  subnet_ids          = module.vpc[each.key].private_subnets
  security_group_ids  = [aws_security_group.vpce[each.key].id]
  tags                = each.value.labels
}

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "21.10.1"

  for_each = local.clusters

  name                    = each.value.name
  kubernetes_version      = each.value.k8s_version
  endpoint_public_access  = var.public_api_endpoint
  endpoint_private_access = var.private_api_endpoint
  enable_irsa             = true
  enabled_log_types       = var.enable_control_plane_logs ? var.control_plane_log_types : []

  vpc_id     = module.vpc[each.key].vpc_id
  subnet_ids = module.vpc[each.key].private_subnets

  # BYOCNI: Explicit addons only - no vpc-cni, no kube-proxy
  # By not including vpc-cni and kube-proxy in addons map, they won't be installed
  addons = var.enable_coredns_addon ? {
    coredns = {
      most_recent = true
      configuration_values = jsonencode({
        tolerations = [{
          key      = "node.cilium.io/agent-not-ready"
          operator = "Exists"
          effect   = "NoSchedule"
        }]
      })
    }
  } : {}

  # Node groups will be created separately after Cilium installation
  # This ensures Cilium is ready before nodes join the cluster

  fargate_profiles = local.fargate_enabled ? {
    for k, v in local.all_fargate_profiles : k => {
      name       = v.name
      selectors  = v.selectors
      subnet_ids = length(v.subnet_ids) > 0 ? v.subnet_ids : module.vpc[each.key].private_subnets
      tags       = v.tags
    }
  } : {}

  encryption_config = var.enable_secrets_encryption ? {
    provider_key_arn = aws_kms_key.cluster[each.key].arn
    resources        = ["secrets"]
  } : null

  access_entries = merge(
    { for arn in var.admin_role_arns : arn => {
      principal_arn     = arn
      kubernetes_groups = ["system:masters", "platform:admin"]
      }
    },
    { for arn in var.readonly_role_arns : arn => {
      principal_arn     = arn
      kubernetes_groups = ["platform:readonly"]
      }
    }
  )

  # Tag node security group for Karpenter discovery
  node_security_group_tags = {
    "karpenter.sh/discovery" = each.value.name
  }

  tags = merge(each.value.labels, {
    "kubernetes.io/cluster/${each.value.name}" = "owned"
  })
}

#--------------------------------------------------------------------------------
# Separate Node Groups - Created AFTER Cilium Installation
#--------------------------------------------------------------------------------

# Node IAM Role
resource "aws_iam_role" "node_group" {
  for_each = var.enable_fargate ? {} : local.clusters

  name_prefix = "${each.value.name}-node-group-"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "ec2.amazonaws.com"
      }
    }]
  })

  tags = merge(each.value.labels, {
    "kubernetes.io/cluster/${each.value.name}" = "owned"
  })
}

# Node IAM Policy Attachments
resource "aws_iam_role_policy_attachment" "node_group_AmazonEKSWorkerNodePolicy" {
  for_each   = aws_iam_role.node_group
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
  role       = each.value.name
}

resource "aws_iam_role_policy_attachment" "node_group_AmazonEKS_CNI_Policy" {
  for_each   = aws_iam_role.node_group
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  role       = each.value.name
}

resource "aws_iam_role_policy_attachment" "node_group_AmazonEC2ContainerRegistryReadOnly" {
  for_each   = aws_iam_role.node_group
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  role       = each.value.name
}

resource "aws_iam_role_policy_attachment" "node_group_AmazonSSMManagedInstanceCore" {
  for_each   = aws_iam_role.node_group
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
  role       = each.value.name
}

# EKS Node Groups - Depend on Cilium being installed first
resource "aws_eks_node_group" "default" {
  for_each = var.enable_fargate ? {} : local.clusters

  cluster_name    = module.eks[each.key].cluster_name
  node_group_name = "${each.value.name}-default-ng"
  node_role_arn   = aws_iam_role.node_group[each.key].arn
  subnet_ids      = module.vpc[each.key].private_subnets
  version         = each.value.k8s_version

  scaling_config {
    desired_size = each.value.nodes.desired
    min_size     = var.environment == "prod" ? each.value.nodes.desired : 1  # Allow scale-down in non-prod
    max_size     = each.value.nodes.desired * 3  # Allow more burst capacity
  }

  update_config {
    max_unavailable_percentage = 33
  }

  ami_type       = "AL2_x86_64"
  instance_types = [each.value.nodes.node_type]

  # Taint nodes until Cilium agent is ready
  taint {
    key    = "node.cilium.io/agent-not-ready"
    value  = "true"
    effect = "NO_EXECUTE"
  }

  tags = merge(each.value.labels, {
    "kubernetes.io/cluster/${each.value.name}" = "owned"
    "karpenter.sh/discovery"                   = each.value.name
  })

  lifecycle {
    create_before_destroy = false
    ignore_changes        = [scaling_config[0].desired_size]
  }

  depends_on = [
    aws_iam_role_policy_attachment.node_group_AmazonEKSWorkerNodePolicy,
    aws_iam_role_policy_attachment.node_group_AmazonEKS_CNI_Policy,
    aws_iam_role_policy_attachment.node_group_AmazonEC2ContainerRegistryReadOnly,
    aws_iam_role_policy_attachment.node_group_AmazonSSMManagedInstanceCore,
  ]
}

# Dedicated IAM role for the EBS CSI addon using IRSA per cluster
resource "aws_iam_role" "ebs_csi" {
  for_each = local.clusters

  name_prefix = "${each.value.name}-ebs-csi-"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRoleWithWebIdentity"
      Effect = "Allow"
      Principal = {
        Federated = module.eks[each.key].oidc_provider_arn
      }
      Condition = {
        StringEquals = {
          "${replace(module.eks[each.key].cluster_oidc_issuer_url, "https://", "")}:sub" = local.ebs_csi_service_account
          "${replace(module.eks[each.key].cluster_oidc_issuer_url, "https://", "")}:aud" = "sts.amazonaws.com"
        }
      }
    }]
  })

  tags = merge(each.value.labels, {
    "kubernetes.io/cluster/${each.value.name}" = "owned"
    addon                                      = "aws-ebs-csi-driver"
  })
}

resource "aws_iam_role_policy_attachment" "ebs_csi" {
  for_each = aws_iam_role.ebs_csi

  role       = each.value.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
}

resource "aws_iam_role" "managed_addons" {
  for_each = local.managed_addon_role_specs

  name_prefix = local.managed_addon_role_names[each.key]
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRoleWithWebIdentity"
      Effect = "Allow"
      Principal = {
        Federated = module.eks[each.value.cluster_key].oidc_provider_arn
      }
      Condition = {
        StringEquals = {
          "${replace(module.eks[each.value.cluster_key].cluster_oidc_issuer_url, "https://", "")}:sub" = "system:serviceaccount:${each.value.namespace}:${each.value.service_account}"
          "${replace(module.eks[each.value.cluster_key].cluster_oidc_issuer_url, "https://", "")}:aud" = "sts.amazonaws.com"
        }
      }
    }]
  })

  tags = merge(local.clusters[each.value.cluster_key].labels, {
    "kubernetes.io/cluster/${local.clusters[each.value.cluster_key].name}" = "owned"
    addon                                                                  = each.value.addon_name
  })
}

resource "aws_iam_role_policy_attachment" "managed_addons" {
  for_each = local.managed_addon_role_policy_keys

  role       = aws_iam_role.managed_addons[each.value.role_key].name
  policy_arn = each.value.policy_arn
}

resource "aws_eks_pod_identity_association" "managed_addons" {
  for_each = local.managed_addon_pod_identity_specs

  cluster_name    = module.eks[each.value.cluster_key].cluster_name
  namespace       = each.value.namespace
  service_account = each.value.service_account
  role_arn        = aws_iam_role.managed_addons[each.key].arn
}

data "aws_eks_addon_version" "ebs_csi" {
  for_each = local.clusters

  addon_name         = "aws-ebs-csi-driver"
  kubernetes_version = module.eks[each.key].cluster_version
  most_recent        = coalesce(try(local.ebs_csi_addon_config.most_recent, null), true)
}

resource "aws_eks_addon" "ebs_csi" {
  for_each = local.clusters

  cluster_name                = module.eks[each.key].cluster_name
  addon_name                  = "aws-ebs-csi-driver"
  addon_version               = coalesce(try(local.ebs_csi_addon_config.addon_version, null), data.aws_eks_addon_version.ebs_csi[each.key].version)
  service_account_role_arn    = aws_iam_role.ebs_csi[each.key].arn
  configuration_values        = try(local.ebs_csi_addon_config.configuration_values, null)
  preserve                    = try(local.ebs_csi_addon_config.preserve, true)
  resolve_conflicts_on_create = try(local.ebs_csi_addon_config.resolve_conflicts_on_create, "OVERWRITE")
  resolve_conflicts_on_update = try(local.ebs_csi_addon_config.resolve_conflicts_on_update, "OVERWRITE")

  timeouts {
    create = try(local.ebs_csi_addon_config.timeouts.create, null)
    update = try(local.ebs_csi_addon_config.timeouts.update, null)
    delete = try(local.ebs_csi_addon_config.timeouts.delete, null)
  }

  tags = merge(each.value.labels, try(local.ebs_csi_addon_config.tags, {}))

  depends_on = [aws_iam_role_policy_attachment.ebs_csi]
}

data "aws_eks_addon_version" "managed" {
  for_each = local.managed_addon_instances

  addon_name         = each.value.spec.addon_name
  kubernetes_version = module.eks[each.value.cluster_key].cluster_version
  most_recent        = coalesce(try(each.value.spec.most_recent, null), true)
}

resource "aws_eks_addon" "managed" {
  for_each = local.managed_addon_instances

  cluster_name                = module.eks[each.value.cluster_key].cluster_name
  addon_name                  = each.value.spec.addon_name
  addon_version               = coalesce(try(each.value.spec.addon_version, null), data.aws_eks_addon_version.managed[each.key].version)
  configuration_values        = try(each.value.spec.configuration_values, null)
  preserve                    = try(each.value.spec.preserve, true)
  resolve_conflicts_on_create = try(each.value.spec.resolve_conflicts_on_create, "OVERWRITE")
  resolve_conflicts_on_update = try(each.value.spec.resolve_conflicts_on_update, "OVERWRITE")

  tags = merge(local.clusters[each.value.cluster_key].labels, try(each.value.spec.tags, {}))

  service_account_role_arn = (
    length(local.addon_role_keys_by_instance[each.key]) == 1 &&
    !contains(keys(local.managed_addon_pod_identity_specs), local.addon_role_keys_by_instance[each.key][0])
  ) ? aws_iam_role.managed_addons[local.addon_role_keys_by_instance[each.key][0]].arn : null

  timeouts {
    create = try(each.value.spec.timeouts.create, null)
    update = try(each.value.spec.timeouts.update, null)
    delete = try(each.value.spec.timeouts.delete, null)
  }
}

resource "aws_cloudwatch_log_group" "eks_control_plane" {
  for_each          = var.manage_control_plane_log_group ? { for name in local.cluster_names : name => name } : {}
  name              = "/aws/eks/${each.value}/cluster"
  retention_in_days = var.cw_log_retention_days
}

resource "aws_kms_key" "cluster" {
  for_each            = var.enable_secrets_encryption ? local.clusters : {}
  description         = "EKS secrets encryption key for ${each.value.name}"
  enable_key_rotation = true
}

resource "aws_kms_alias" "cluster" {
  for_each      = var.enable_secrets_encryption ? local.clusters : {}
  name          = "alias/${var.kms_alias_prefix}-${each.value.name}"
  target_key_id = aws_kms_key.cluster[each.key].key_id
}

# Tag cluster security groups for Karpenter discovery
resource "aws_ec2_tag" "cluster_sg_karpenter" {
  for_each    = local.clusters
  resource_id = module.eks[each.key].cluster_security_group_id
  key         = "karpenter.sh/discovery"
  value       = each.value.name
}

# EKS Access Entries for Terraform admin principals (hub cluster only)
locals {
  hub_cluster_name           = local.cluster_names[0]
  caller_resource            = element(split(":", data.aws_caller_identity.terraform.arn), 5)
  caller_role_name           = startswith(local.caller_resource, "assumed-role") ? element(split("/", local.caller_resource), 1) : null
  derived_terraform_role_arn = local.caller_role_name != null ? "arn:aws:iam::${data.aws_caller_identity.terraform.account_id}:role/${local.caller_role_name}" : data.aws_caller_identity.terraform.arn
  terraform_access_arns = length(var.terraform_admin_role_arns) > 0 ? var.terraform_admin_role_arns : (
    local.derived_terraform_role_arn != "" ? [local.derived_terraform_role_arn] : []
  )
}

resource "aws_eks_access_entry" "terraform_admin" {
  for_each      = toset(local.terraform_access_arns)
  cluster_name  = module.eks[local.hub_cluster_name].cluster_name
  principal_arn = each.value
  type          = "STANDARD"
}

resource "aws_eks_access_policy_association" "terraform_admin" {
  for_each      = aws_eks_access_entry.terraform_admin
  cluster_name  = each.value.cluster_name
  principal_arn = each.value.principal_arn
  policy_arn    = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
  access_scope {
    type = "cluster"
  }
}

#--------------------------------------------------------------------------------
# Karpenter Interruption Handling (SQS + EventBridge)
#--------------------------------------------------------------------------------

# SQS queue for Karpenter interruption notifications
resource "aws_sqs_queue" "karpenter" {
  for_each = local.clusters

  name                      = "${each.value.name}-karpenter"
  message_retention_seconds = 300
  sqs_managed_sse_enabled   = true

  tags = merge(each.value.labels, {
    purpose = "karpenter-interruption-handling"
  })
}

resource "aws_sqs_queue_policy" "karpenter" {
  for_each  = local.clusters
  queue_url = aws_sqs_queue.karpenter[each.key].url

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowEventsToSendMessages"
        Effect = "Allow"
        Principal = {
          Service = "events.amazonaws.com"
        }
        Action   = "sqs:SendMessage"
        Resource = aws_sqs_queue.karpenter[each.key].arn
      },
      {
        Sid    = "AllowEventsSqs"
        Effect = "Allow"
        Principal = {
          Service = "sqs.amazonaws.com"
        }
        Action   = "sqs:SendMessage"
        Resource = aws_sqs_queue.karpenter[each.key].arn
      }
    ]
  })
}

# EventBridge rules for EC2 instance interruptions
resource "aws_cloudwatch_event_rule" "karpenter_spot_interruption" {
  for_each = local.clusters

  name        = "${each.value.name}-karpenter-spot-interruption"
  description = "EC2 Spot Instance Interruption Warning"

  event_pattern = jsonencode({
    source      = ["aws.ec2"]
    detail-type = ["EC2 Spot Instance Interruption Warning"]
  })

  tags = each.value.labels
}

resource "aws_cloudwatch_event_target" "karpenter_spot_interruption" {
  for_each = local.clusters

  rule      = aws_cloudwatch_event_rule.karpenter_spot_interruption[each.key].name
  target_id = "KarpenterInterruptionQueue"
  arn       = aws_sqs_queue.karpenter[each.key].arn
}

resource "aws_cloudwatch_event_rule" "karpenter_instance_rebalance" {
  for_each = local.clusters

  name        = "${each.value.name}-karpenter-instance-rebalance"
  description = "EC2 Instance Rebalance Recommendation"

  event_pattern = jsonencode({
    source      = ["aws.ec2"]
    detail-type = ["EC2 Instance Rebalance Recommendation"]
  })

  tags = each.value.labels
}

resource "aws_cloudwatch_event_target" "karpenter_instance_rebalance" {
  for_each = local.clusters

  rule      = aws_cloudwatch_event_rule.karpenter_instance_rebalance[each.key].name
  target_id = "KarpenterInterruptionQueue"
  arn       = aws_sqs_queue.karpenter[each.key].arn
}

resource "aws_cloudwatch_event_rule" "karpenter_instance_state_change" {
  for_each = local.clusters

  name        = "${each.value.name}-karpenter-instance-state-change"
  description = "EC2 Instance State-change Notification"

  event_pattern = jsonencode({
    source      = ["aws.ec2"]
    detail-type = ["EC2 Instance State-change Notification"]
  })

  tags = each.value.labels
}

resource "aws_cloudwatch_event_target" "karpenter_instance_state_change" {
  for_each = local.clusters

  rule      = aws_cloudwatch_event_rule.karpenter_instance_state_change[each.key].name
  target_id = "KarpenterInterruptionQueue"
  arn       = aws_sqs_queue.karpenter[each.key].arn
}

resource "aws_cloudwatch_event_rule" "karpenter_scheduled_change" {
  for_each = local.clusters

  name        = "${each.value.name}-karpenter-scheduled-change"
  description = "AWS Health Event"

  event_pattern = jsonencode({
    source      = ["aws.health"]
    detail-type = ["AWS Health Event"]
  })

  tags = each.value.labels
}

resource "aws_cloudwatch_event_target" "karpenter_scheduled_change" {
  for_each = local.clusters

  rule      = aws_cloudwatch_event_rule.karpenter_scheduled_change[each.key].name
  target_id = "KarpenterInterruptionQueue"
  arn       = aws_sqs_queue.karpenter[each.key].arn
}

# Install Cilium CNI on each cluster (optional, replaces AWS VPC CNI)
# Automatically disabled if Fargate is enabled (incompatible)
# TODO: Cilium installation requires dynamic provider configuration per cluster
# This creates a circular dependency and needs to be handled separately
# For now, Cilium must be installed via a separate Terraform workspace or Helm CLI
/*
module "cilium" {
  source   = "../networking/cilium"
  for_each = local.cilium_enabled ? local.clusters : {}

  install      = true
  cluster_name = each.value.name
  cluster_id   = index(local.cluster_names, each.key) + 1

  # Hubble observability
  hubble_relay_enabled   = var.enable_hubble
  hubble_ui_enabled      = var.enable_hubble
  hubble_metrics_enabled = var.enable_hubble

  # Performance features
  bandwidth_manager_enabled = true
  kube_proxy_replacement    = var.enable_kube_proxy_replacement

  # Cluster mesh for multi-cluster networking
  clustermesh_enabled  = var.enable_cluster_mesh && var.cluster_count > 1
  clustermesh_clusters = var.enable_cluster_mesh && var.cluster_count > 1 ? local.cluster_names : []

  # Security
  policy_enforcement_mode = "default"
  enable_encryption       = false # Start without encryption for max performance

  # Monitoring integration
  enable_prometheus_servicemonitor = true

  cilium_version = var.cilium_version
  tags           = each.value.labels

  # Note: This module requires provider configuration
  # Providers must be passed from the calling environment
  providers = {
    kubernetes = kubernetes
    helm       = helm
  }

  depends_on = [module.eks]
}
*/

