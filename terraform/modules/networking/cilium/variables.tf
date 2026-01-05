variable "install" {
  description = "Whether to install Cilium"
  type        = bool
  default     = true
}

variable "namespace" {
  description = "Kubernetes namespace for Cilium"
  type        = string
  default     = "kube-system"
}

variable "cilium_version" {
  description = "Cilium Helm chart version"
  type        = string
  default     = "1.16.5" # Latest stable as of 2026-01
}

variable "cluster_name" {
  description = "EKS cluster name"
  type        = string
}

variable "cluster_id" {
  description = "Unique cluster ID for cluster mesh (1-255)"
  type        = number
  default     = 1
  validation {
    condition     = var.cluster_id >= 1 && var.cluster_id <= 255
    error_message = "Cluster ID must be between 1 and 255"
  }
}

variable "cluster_endpoint" {
  description = "EKS cluster API endpoint (for k8sServiceHost in kube-proxy replacement mode)"
  type        = string
}

variable "cluster_endpoint_port" {
  description = "EKS cluster API port (for k8sServicePort in kube-proxy replacement mode)"
  type        = number
  default     = 443
}

# Hubble Configuration
variable "hubble_relay_enabled" {
  description = "Enable Hubble Relay for observability"
  type        = bool
  default     = true
}

variable "hubble_relay_replicas" {
  description = "Number of Hubble Relay replicas"
  type        = number
  default     = 2
}

variable "hubble_ui_enabled" {
  description = "Enable Hubble UI"
  type        = bool
  default     = true
}

variable "hubble_ingress_enabled" {
  description = "Enable ingress for Hubble UI"
  type        = bool
  default     = false
}

variable "hubble_ingress_annotations" {
  description = "Annotations for Hubble UI ingress"
  type        = map(string)
  default     = {}
}

variable "hubble_hostname" {
  description = "Hostname for Hubble UI"
  type        = string
  default     = "hubble.example.com"
}

variable "hubble_metrics_enabled" {
  description = "Enable Hubble metrics for Prometheus"
  type        = bool
  default     = true
}

# Performance Features
variable "bandwidth_manager_enabled" {
  description = "Enable bandwidth manager for fair queueing"
  type        = bool
  default     = true
}

variable "kube_proxy_replacement" {
  description = "Replace kube-proxy with Cilium (recommended for performance)"
  type        = bool
  default     = true
}

# BGP Configuration
variable "bgp_enabled" {
  description = "Enable BGP for hybrid/bare-metal nodes"
  type        = bool
  default     = false
}

variable "bgp_announce_lb" {
  description = "Announce LoadBalancer IPs via BGP"
  type        = bool
  default     = false
}

variable "bgp_announce_pod_cidr" {
  description = "Announce Pod CIDR via BGP"
  type        = bool
  default     = false
}

# Cluster Mesh Configuration
variable "clustermesh_enabled" {
  description = "Enable Cluster Mesh for multi-cluster networking"
  type        = bool
  default     = false
}

variable "clustermesh_clusters" {
  description = "List of cluster names for mesh"
  type        = list(string)
  default     = []
}

variable "clustermesh_remote_clusters" {
  description = "Remote cluster configurations for mesh"
  type = map(object({
    cluster_id  = number
    addresses   = list(string)
    ca_cert     = string
    client_cert = string
    client_key  = string
  }))
  default = {}
}

# Security
variable "policy_enforcement_mode" {
  description = "Network policy enforcement mode (default, always, never)"
  type        = string
  default     = "default"
  validation {
    condition     = contains(["default", "always", "never"], var.policy_enforcement_mode)
    error_message = "Must be one of: default, always, never"
  }
}

variable "enable_encryption" {
  description = "Enable WireGuard encryption (impacts performance)"
  type        = bool
  default     = false
}

variable "security_groups_for_pods" {
  description = "Enable AWS security groups for pods"
  type        = bool
  default     = false
}

# Monitoring
variable "enable_prometheus_servicemonitor" {
  description = "Create Prometheus ServiceMonitor resources"
  type        = bool
  default     = true
}

# Sample Policies
variable "create_sample_policies" {
  description = "Create sample Cilium network policies"
  type        = bool
  default     = false
}

# Resource Configuration
variable "cilium_resources" {
  description = "Resource limits for Cilium agent"
  type = object({
    limits = optional(object({
      cpu    = optional(string, "1000m")
      memory = optional(string, "1Gi")
    }))
    requests = optional(object({
      cpu    = optional(string, "100m")
      memory = optional(string, "128Mi")
    }))
  })
  default = {
    limits = {
      cpu    = "1000m"
      memory = "1Gi"
    }
    requests = {
      cpu    = "100m"
      memory = "128Mi"
    }
  }
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}

variable "remove_aws_node" {
  description = "Automatically remove AWS VPC CNI daemonset for full Cilium replacement"
  type        = bool
  default     = true
}
