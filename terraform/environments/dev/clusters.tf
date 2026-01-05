module "cluster_factory" {
  source                            = "../../modules/cluster_factory"
  region                            = var.region
  cluster_count                     = var.cluster_count
  cluster_config                    = var.cluster_config
  name_prefix                       = var.name_prefix
  environment                       = "dev"
  base_cidr                         = "10.0.0.0/8"
  admin_role_arns                   = var.admin_role_arns
  readonly_role_arns                = var.readonly_role_arns
  terraform_admin_role_arns         = var.terraform_admin_role_arns

  # Cost allocation and compliance tags
  cost_center              = "engineering"
  project                  = "dev-mlops"
  owner                    = "platform-team"
  compliance_requirements  = "none"
  data_classification      = "internal"
  backup_policy            = "daily"
  enable_cilium                     = true # Enabled: Cilium is installed separately after cluster creation
  enable_cloudwatch_observability   = var.enable_cloudwatch_observability
  enable_guardduty_runtime          = var.enable_guardduty_runtime
  enable_network_flow_monitor       = var.enable_network_flow_monitor
  enable_node_monitoring_agent      = var.enable_node_monitoring_agent
  enable_pod_identity_agent         = var.enable_pod_identity_agent
  enable_secrets_store_provider     = var.enable_secrets_store_provider
  enable_hyperpod_observability     = var.enable_hyperpod_observability
  enable_hyperpod_task_governance   = var.enable_hyperpod_task_governance
  enable_hyperpod_training_operator = var.enable_hyperpod_training_operator
  enable_sagemaker_spaces           = var.enable_sagemaker_spaces
  enable_aws_vpc_cni_addon          = var.enable_aws_vpc_cni_addon
  enable_kube_proxy_addon           = var.enable_kube_proxy_addon
  enable_coredns_addon              = var.enable_coredns_addon
  argocd_capability                 = var.argocd_capability
}

# Install Cilium CNI on hub cluster (BYOCNI: Full CNI replacement, no chaining)
# Cilium provides complete networking: CNI, IPAM, network policies, kube-proxy replacement
# Maximum performance with native routing and eBPF
module "cilium_hub" {
  source = "../../modules/networking/cilium"

  install      = true
  cluster_name = module.cluster_factory.cluster_names[0]
  cluster_id   = 1

  # Cluster endpoint for kube-proxy replacement
  cluster_endpoint      = module.cluster_factory.cluster_endpoints[module.cluster_factory.cluster_names[0]]
  cluster_endpoint_port = 443

  # Hubble observability
  hubble_relay_enabled   = true
  hubble_ui_enabled      = true
  hubble_metrics_enabled = true

  # Performance features
  bandwidth_manager_enabled = true
  kube_proxy_replacement    = true # Enabled: Cilium replaces kube-proxy with eBPF

  # Cluster mesh disabled for single hub cluster
  clustermesh_enabled  = false
  clustermesh_clusters = []

  # Security
  policy_enforcement_mode = "default"
  enable_encryption       = true  # WireGuard transparent encryption for pod-to-pod traffic

  # Monitoring (Prometheus Operator CRDs installed via helm_release.prometheus_operator_crds)
  enable_prometheus_servicemonitor = true

  cilium_version = "1.16.5"
  tags           = { cluster = module.cluster_factory.cluster_names[0], environment = "dev" }

  providers = {
    kubernetes = kubernetes.hub
    helm       = helm.hub
  }

  depends_on = [helm_release.prometheus_operator_crds]
}

module "config" {
  source      = "../../modules/config/loader"
  config_path = var.platform_config_path
  environment = "dev"
}

# Karpenter - Phase 2: Node autoscaling and lifecycle management
module "karpenter" {
  source           = "../../modules/karpenter"
  count            = var.enable_karpenter ? 1 : 0
  cluster_name     = module.cluster_factory.cluster_names[0]
  cluster_endpoint = module.cluster_factory.cluster_endpoints[module.cluster_factory.cluster_names[0]]
  oidc_issuer_url  = module.cluster_factory.cluster_oidc_issuer_urls[module.cluster_factory.cluster_names[0]]
  region           = var.region

  # Install Karpenter via Terraform (NodePools deployed via ArgoCD)
  install                 = true
  karpenter_chart_version = "1.1.1"

  tags = {
    cluster     = module.cluster_factory.cluster_names[0]
    environment = "dev"
  }

  providers = {
    kubernetes = kubernetes.hub
    helm       = helm.hub
  }

  depends_on = [
    module.cilium_hub,
    module.cluster_factory
  ]
}

# Velero - Disaster Recovery Backup
module "velero" {
  source = "../../modules/backup/velero"
  count  = var.enable_velero ? 1 : 0

  cluster_name       = module.cluster_factory.cluster_names[0]
  region             = var.region
  oidc_provider_arn  = module.cluster_factory.cluster_oidc_providers[module.cluster_factory.cluster_names[0]]
  oidc_issuer_url    = module.cluster_factory.cluster_oidc_issuer_urls[module.cluster_factory.cluster_names[0]]

  install                 = true
  backup_retention_days   = 30
  enable_service_monitor  = true

  backup_schedules = {
    daily = {
      schedule = "0 2 * * *"  # 2 AM daily
      template = {
        ttl                     = "720h"  # 30 days
        includeClusterResources = true
        snapshotVolumes         = true
      }
    }
    weekly = {
      schedule = "0 3 * * 0"  # 3 AM Sunday
      template = {
        ttl                     = "2160h"  # 90 days
        includeClusterResources = true
        snapshotVolumes         = true
      }
    }
  }

  tags = {
    cluster     = module.cluster_factory.cluster_names[0]
    environment = "dev"
    backup      = "velero"
  }

  providers = {
    kubernetes = kubernetes.hub
    helm       = helm.hub
  }

  depends_on = [
    module.cilium_hub,
    module.cluster_factory,
    helm_release.prometheus_operator_crds
  ]
}

# Amazon Managed Grafana - SLO/SLI visualization
module "managed_grafana" {
  source = "../../modules/observability/managed_grafana"
  count  = var.enable_amg ? 1 : 0

  environment                 = "dev"
  account_access_type         = "CURRENT_ACCOUNT"
  authentication_providers    = ["AWS_SSO"]
  permission_type             = "SERVICE_MANAGED"
  data_sources                = ["PROMETHEUS", "CLOUDWATCH", "XRAY"]
  notification_destinations   = ["SNS"]

  create_iam_role = true
  create_api_key  = false

  tags = {
    cluster     = module.cluster_factory.cluster_names[0]
    environment = "dev"
    purpose     = "slo-monitoring"
  }
}

# KEDA - Event-driven autoscaling
module "keda" {
  source = "../../modules/autoscaling/keda"
  count  = var.enable_keda ? 1 : 0

  cluster_name       = module.cluster_factory.cluster_names[0]
  namespace          = "keda"
  create_namespace   = true

  # IRSA for AWS service access (SQS, CloudWatch, DynamoDB, Kinesis)
  enable_irsa        = true
  oidc_provider_arn  = module.cluster_factory.cluster_oidc_providers[module.cluster_factory.cluster_names[0]]
  oidc_issuer_url    = module.cluster_factory.cluster_oidc_issuer_urls[module.cluster_factory.cluster_names[0]]

  # High availability
  replicas           = 2
  enable_pdb         = true
  pdb_min_available  = 1

  # Monitoring
  enable_prometheus_servicemonitor = true

  keda_version = "2.16.0"

  tags = {
    cluster     = module.cluster_factory.cluster_names[0]
    environment = "dev"
    purpose     = "autoscaling"
  }

  providers = {
    kubernetes = kubernetes.hub
    helm       = helm.hub
  }

  depends_on = [
    module.cilium_hub,
    module.cluster_factory,
    helm_release.prometheus_operator_crds
  ]
}
