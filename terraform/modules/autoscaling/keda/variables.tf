variable "install" {
  description = "Whether to install KEDA"
  type        = bool
  default     = true
}

variable "cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
}

variable "namespace" {
  description = "Kubernetes namespace for KEDA"
  type        = string
  default     = "keda"
}

variable "create_namespace" {
  description = "Create the namespace for KEDA"
  type        = bool
  default     = true
}

variable "keda_version" {
  description = "KEDA Helm chart version"
  type        = string
  default     = "2.16.0"
}

# IRSA Configuration
variable "enable_irsa" {
  description = "Enable IAM Roles for Service Accounts"
  type        = bool
  default     = true
}

variable "oidc_provider_arn" {
  description = "ARN of the OIDC provider for IRSA"
  type        = string
  default     = ""
}

variable "oidc_issuer_url" {
  description = "OIDC issuer URL without https://"
  type        = string
  default     = ""
}

variable "create_service_account" {
  description = "Create Kubernetes service account for KEDA"
  type        = bool
  default     = true
}

variable "service_account_name" {
  description = "Name of the service account"
  type        = string
  default     = "keda-operator"
}

# Resource Configuration
variable "operator_resources" {
  description = "Resource limits and requests for KEDA operator"
  type = object({
    limits_cpu      = string
    limits_memory   = string
    requests_cpu    = string
    requests_memory = string
  })
  default = {
    limits_cpu      = "1000m"
    limits_memory   = "1000Mi"
    requests_cpu    = "100m"
    requests_memory = "100Mi"
  }
}

variable "metrics_server_resources" {
  description = "Resource limits and requests for KEDA metrics server"
  type = object({
    limits_cpu      = string
    limits_memory   = string
    requests_cpu    = string
    requests_memory = string
  })
  default = {
    limits_cpu      = "1000m"
    limits_memory   = "1000Mi"
    requests_cpu    = "100m"
    requests_memory = "100Mi"
  }
}

# High Availability
variable "replicas" {
  description = "Number of KEDA operator replicas"
  type        = number
  default     = 2
}

variable "enable_pdb" {
  description = "Enable Pod Disruption Budget"
  type        = bool
  default     = true
}

variable "pdb_min_available" {
  description = "Minimum available pods for PDB"
  type        = number
  default     = 1
}

# Monitoring
variable "enable_prometheus_servicemonitor" {
  description = "Enable Prometheus ServiceMonitor for metrics collection"
  type        = bool
  default     = true
}

variable "tags" {
  description = "Tags to apply to AWS resources"
  type        = map(string)
  default     = {}
}
