variable "region" {
  description = "AWS region where clusters will be created"
  type        = string

  validation {
    condition     = can(regex("^[a-z]{2}-[a-z]+-\\d{1}$", var.region))
    error_message = "Region must be a valid AWS region format (e.g., us-east-1)."
  }
}

variable "cluster_count" {
  description = "Number of EKS clusters to create (first becomes hub/management cluster)"
  type        = number
  default     = 1

  validation {
    condition     = var.cluster_count >= 1 && var.cluster_count <= 50
    error_message = "Cluster count must be between 1 and 50."
  }
}

variable "cluster_config" {
  description = "Cluster configuration settings"
  type = object({
    type         = string # mlops, data, general
    size         = string # small, medium, large, xlarge
    tenancy      = string # shared, dedicated
    compliance   = string # none, pci, hipaa, soc2
    auto_upgrade = bool
    version      = optional(string, "1.30")
  })

  validation {
    condition     = contains(["small", "medium", "large", "xlarge"], var.cluster_config.size)
    error_message = "Size must be one of: small, medium, large, xlarge."
  }

  validation {
    condition     = contains(["shared", "dedicated"], var.cluster_config.tenancy)
    error_message = "Tenancy must be either 'shared' or 'dedicated'."
  }
}

variable "name_prefix" {
  description = "Prefix for cluster names (e.g., dev-mlops, qa-mlops, prod-mlops)"
  type        = string
  default     = "mlops"
}

variable "environment" {
  description = "Environment label: dev|qa|prod|sandbox"
  type        = string
  default     = "dev"

  validation {
    condition     = contains(["dev", "qa", "prod", "sandbox"], var.environment)
    error_message = "Environment must be one of: dev, qa, prod, sandbox."
  }
}

variable "base_cidr" {
  description = "Base CIDR block to derive per-cluster VPC CIDRs (e.g., 10.0.0.0/8)"
  type        = string
  default     = "10.0.0.0/8"
}

variable "public_api_endpoint" {
  description = "Expose EKS API publicly"
  type        = bool
  default     = true
}

variable "private_api_endpoint" {
  description = "Enable private endpoint access"
  type        = bool
  default     = true
}

variable "enable_secrets_encryption" {
  description = "Encrypt Kubernetes Secrets with KMS"
  type        = bool
  default     = true
}

variable "kms_alias_prefix" {
  description = "Prefix for KMS aliases per cluster"
  type        = string
  default     = "eks-secrets"
}

variable "enable_vpc_endpoints" {
  description = "Create VPC endpoints for S3/ECR/STS/Logs/etc."
  type        = bool
  default     = true
}

variable "enable_control_plane_logs" {
  description = "Enable EKS control plane logs to CloudWatch"
  type        = bool
  default     = true
}

variable "control_plane_log_types" {
  description = "Which control plane logs to enable"
  type        = list(string)
  default     = ["api", "audit", "authenticator", "controllerManager", "scheduler"]
}

variable "cw_log_retention_days" {
  description = "CloudWatch log retention for EKS control plane logs"
  type        = number
  default     = 400
}

variable "manage_control_plane_log_group" {
  description = "Whether Terraform should manage the /aws/eks/<cluster>/cluster log group (set true only if the log group does not already exist or has been imported)"
  type        = bool
  default     = false
}

variable "admin_role_arns" {
  description = "IAM role ARNs that should have admin access to clusters"
  type        = list(string)
  default     = []
}

variable "readonly_role_arns" {
  description = "IAM role ARNs that should have read-only access to clusters"
  type        = list(string)
  default     = []
}

variable "terraform_admin_role_arns" {
  description = "IAM principals (e.g., Terraform executor roles) that should automatically receive cluster-admin access via EKS Access Entries"
  type        = list(string)
  default     = []
}

variable "enable_cilium" {
  description = "Install Cilium CNI (always enabled - Cilium is the default CNI)"
  type        = bool
  default     = true
}

variable "cilium_version" {
  description = "Cilium Helm chart version"
  type        = string
  default     = "1.16.5"
}

variable "enable_hubble" {
  description = "Enable Hubble for network observability (requires Cilium)"
  type        = bool
  default     = true
}

variable "enable_kube_proxy_replacement" {
  description = "Replace kube-proxy with Cilium for better performance (requires Cilium)"
  type        = bool
  default     = true
}

variable "enable_cluster_mesh" {
  description = "Enable Cilium Cluster Mesh for multi-cluster networking (requires Cilium and cluster_count > 1)"
  type        = bool
  default     = false
}

variable "enable_fargate" {
  description = "Enable AWS Fargate profiles (incompatible with Cilium - will auto-disable Cilium)"
  type        = bool
  default     = false
}

variable "fargate_profiles" {
  description = "Map of Fargate profile configurations"
  type = map(object({
    name = string
    selectors = list(object({
      namespace = string
      labels    = optional(map(string), {})
    }))
    subnet_ids = optional(list(string), [])
    tags       = optional(map(string), {})
  }))
  default = {}
}

variable "fargate_profile_defaults" {
  description = "Default Fargate profile for serverless workloads"
  type = object({
    namespaces = list(string)
  })
  default = {
    namespaces = ["fargate", "serverless"]
  }
}

variable "enable_cloudwatch_observability" {
  description = "Enable Amazon CloudWatch Observability EKS addon for metrics, logs, and traces"
  type        = bool
  default     = false
}

variable "argocd_capability" {
  description = "Configuration for the AWS-managed Argo CD capability"
  type = object({
    enable                       = bool
    identity_center_instance_arn = string
    admin_group_name             = string
    readonly_group_name          = string
    namespace                    = optional(string, "argocd")
    server_url                   = optional(string, null)
    network_access_type          = optional(string, "PRIVATE") # PUBLIC or PRIVATE
  })
  default = {
    enable                       = true
    identity_center_instance_arn = ""
    admin_group_name             = "platform-admins"
    readonly_group_name          = "platform-readonly"
    namespace                    = "argocd"
    server_url                   = null
    network_access_type          = "PRIVATE"
  }
}

variable "enable_guardduty_runtime" {
  description = "Enable the Amazon GuardDuty EKS Runtime Monitoring add-on"
  type        = bool
  default     = false
}

variable "enable_network_flow_monitor" {
  description = "Enable the AWS Network Flow Monitor Agent add-on"
  type        = bool
  default     = false
}

variable "enable_node_monitoring_agent" {
  description = "Enable the EKS node monitoring agent add-on"
  type        = bool
  default     = false
}

variable "enable_pod_identity_agent" {
  description = "Enable the Amazon EKS Pod Identity Agent add-on (required for pod identity associations)"
  type        = bool
  default     = false
}

variable "enable_secrets_store_provider" {
  description = "Enable the AWS Secrets Store CSI Driver provider add-on"
  type        = bool
  default     = false
}

variable "enable_hyperpod_observability" {
  description = "Enable the Amazon SageMaker HyperPod observability add-on"
  type        = bool
  default     = false
}

variable "enable_hyperpod_task_governance" {
  description = "Enable the Amazon SageMaker HyperPod task governance add-on"
  type        = bool
  default     = false
}

variable "enable_hyperpod_training_operator" {
  description = "Enable the Amazon SageMaker HyperPod training operator add-on"
  type        = bool
  default     = false
}

variable "enable_sagemaker_spaces" {
  description = "Enable the Amazon SageMaker Spaces add-on"
  type        = bool
  default     = false
}

variable "cluster_addons" {
  description = "Map of EKS cluster addon configurations (coredns, vpc-cni, kube-proxy, etc.)"
  type        = any
  default     = {}
}

variable "enable_aws_vpc_cni_addon" {
  description = "Install the AWS VPC CNI managed add-on (set to false only if you bootstrap an alternative CNI like Cilium)"
  type        = bool
  default     = false
}

variable "enable_kube_proxy_addon" {
  description = "Install the AWS-managed kube-proxy add-on (usually disabled when Cilium's kube-proxy replacement is enabled)"
  type        = bool
  default     = false
}

variable "enable_coredns_addon" {
  description = "Install CoreDNS via the AWS-managed add-on (should stay true for Kubernetes DNS even when using Cilium)"
  type        = bool
  default     = false
}

# Cost Allocation and Compliance Tags
variable "cost_center" {
  description = "Cost center for billing allocation"
  type        = string
  default     = "engineering"
}

variable "project" {
  description = "Project name for cost tracking"
  type        = string
  default     = "argoeks"
}

variable "owner" {
  description = "Team or individual responsible for the resources"
  type        = string
  default     = "platform-team"
}

variable "compliance_requirements" {
  description = "Compliance requirements (e.g., PCI-DSS, HIPAA, SOC2)"
  type        = string
  default     = "none"
}

variable "data_classification" {
  description = "Data classification level (public, internal, confidential, restricted)"
  type        = string
  default     = "internal"
}

variable "backup_policy" {
  description = "Backup policy name or retention schedule"
  type        = string
  default     = "standard"
}

variable "additional_tags" {
  description = "Additional tags to merge with standard tags"
  type        = map(string)
  default     = {}
}
