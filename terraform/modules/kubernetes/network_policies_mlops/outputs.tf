output "secured_namespaces" {
  description = "List of namespaces with network policies applied"
  value       = local.secured_namespaces
}

output "cilium_mode_enabled" {
  description = "Whether Cilium NetworkPolicy mode is active"
  value       = var.cilium_mode
}

output "ml_policies_enabled" {
  description = "Whether ML-specific policies are enabled"
  value       = var.enable_ml_policies
}

output "policy_count" {
  description = "Number of network policies created"
  value = var.enabled ? (
    var.cilium_mode ? (
      length(local.secured_namespaces) +
      (var.enable_ml_policies ? length(var.ml_training_namespaces) + length(var.ml_inference_namespaces) : 0) +
      length(var.platform_namespaces)
      ) : (
      length(local.secured_namespaces) * 3
    )
  ) : 0
}
