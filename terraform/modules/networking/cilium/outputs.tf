output "cilium_version" {
  description = "Installed Cilium version"
  value       = var.install ? var.cilium_version : null
}

output "namespace" {
  description = "Namespace where Cilium is installed"
  value       = var.namespace
}

output "hubble_relay_endpoint" {
  description = "Hubble Relay gRPC endpoint"
  value       = var.install && var.hubble_relay_enabled ? "hubble-relay.${var.namespace}.svc.cluster.local:4245" : null
}

output "hubble_ui_enabled" {
  description = "Whether Hubble UI is enabled"
  value       = var.install && var.hubble_ui_enabled
}

output "clustermesh_enabled" {
  description = "Whether Cluster Mesh is enabled"
  value       = var.clustermesh_enabled
}

output "cluster_id" {
  description = "Cluster ID for Cluster Mesh"
  value       = var.cluster_id
}

output "kube_proxy_replacement" {
  description = "Whether kube-proxy is replaced by Cilium"
  value       = var.kube_proxy_replacement
}

output "bandwidth_manager_enabled" {
  description = "Whether bandwidth manager is enabled"
  value       = var.bandwidth_manager_enabled
}

output "policy_enforcement_mode" {
  description = "Network policy enforcement mode"
  value       = var.policy_enforcement_mode
}
