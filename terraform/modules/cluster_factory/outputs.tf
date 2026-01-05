output "cluster_names" {
  description = "List of all created cluster names"
  value       = [for name in local.cluster_names : module.eks[name].cluster_name]
}

output "cluster_endpoints" {
  description = "Map of cluster names to their API server endpoints"
  value       = { for k, v in module.eks : k => v.cluster_endpoint }
}

output "cluster_certificate_authorities" {
  description = "Map of cluster names to their certificate authority data"
  value       = { for k, v in module.eks : k => v.cluster_certificate_authority_data }
  sensitive   = true
}

output "oidc_provider_arns" {
  description = "Map of cluster names to their OIDC provider ARNs"
  value       = { for k, v in module.eks : k => v.oidc_provider_arn }
}

output "cluster_oidc_issuer_urls" {
  description = "Map of cluster names to their OpenID Connect issuer URLs"
  value       = { for k, v in module.eks : k => v.cluster_oidc_issuer_url }
}

output "cluster_oidc_providers" {
  description = "Map of cluster names to their OpenID Connect provider hostpaths (without https://)"
  value       = { for k, v in module.eks : k => v.oidc_provider }
}

output "cluster_oidc_provider_arns" {
  description = "Map of cluster names to their OIDC provider ARNs"
  value       = { for k, v in module.eks : k => v.oidc_provider_arn }
}

output "kms_key_arns" {
  description = "Map of cluster names to their KMS key ARNs for secrets encryption"
  value       = var.enable_secrets_encryption ? { for k, v in aws_kms_key.cluster : k => v.arn } : {}
}

output "vpc_ids" {
  description = "Map of cluster names to their VPC IDs"
  value       = { for k in local.cluster_names : k => module.vpc[k].vpc_id }
}

output "private_subnets" {
  description = "Map of cluster names to their private subnet IDs"
  value       = { for k in local.cluster_names : k => module.vpc[k].private_subnets }
}

output "public_subnets" {
  description = "Map of cluster names to their public subnet IDs"
  value       = { for k in local.cluster_names : k => module.vpc[k].public_subnets }
}

output "private_route_table_ids" {
  description = "Map of cluster names to their private route table IDs"
  value       = { for k in local.cluster_names : k => module.vpc[k].private_route_table_ids }
}

output "cluster_security_group_ids" {
  description = "Map of cluster names to their cluster security group IDs"
  value       = { for k, v in module.eks : k => v.cluster_security_group_id }
}

output "node_security_group_ids" {
  description = "Map of cluster names to their node security group IDs"
  value       = { for k, v in module.eks : k => v.node_security_group_id }
}

output "hub_cluster_name" {
  description = "Name of the first (hub) cluster"
  value       = local.cluster_names[0]
}

output "hub_vpc_id" {
  description = "VPC ID of the hub cluster"
  value       = module.vpc[local.cluster_names[0]].vpc_id
}

output "hub_private_subnets" {
  description = "Private subnet IDs of the hub cluster"
  value       = module.vpc[local.cluster_names[0]].private_subnets
}

output "cilium_enabled" {
  description = "Whether Cilium CNI is actually enabled (auto-disabled if Fargate is enabled)"
  value       = local.cilium_enabled
}

output "cilium_requested" {
  description = "Whether Cilium was requested via variable (may differ from actual if Fargate enabled)"
  value       = var.enable_cilium
}

output "fargate_enabled" {
  description = "Whether Fargate profiles are enabled"
  value       = local.fargate_enabled
}

output "cni_plugin" {
  description = "Active CNI plugin (cilium or aws-vpc-cni)"
  value       = local.cilium_enabled ? "cilium" : "aws-vpc-cni"
}

output "cilium_cluster_ids" {
  description = "Map of cluster names to their Cilium cluster IDs (for cluster mesh)"
  value = local.cilium_enabled ? {
    for idx, name in local.cluster_names : name => idx + 1
  } : {}
}

output "deployment_mode" {
  description = "Cluster deployment mode (ec2-only, ec2-karpenter, ec2-fargate, fargate-only)"
  value = local.fargate_enabled ? (
    length(module.eks) > 0 ? "ec2-fargate-hybrid" : "fargate-only"
  ) : "ec2-karpenter"
}

output "karpenter_interruption_queue_names" {
  description = "Map of cluster names to Karpenter interruption SQS queue names"
  value       = { for k, v in aws_sqs_queue.karpenter : k => v.name }
}

output "karpenter_interruption_queue_urls" {
  description = "Map of cluster names to Karpenter interruption SQS queue URLs"
  value       = { for k, v in aws_sqs_queue.karpenter : k => v.url }
}

output "node_group_ids" {
  description = "Map of cluster names to their node group IDs"
  value       = { for k, v in aws_eks_node_group.default : k => v.id }
}

output "node_iam_role_arns" {
  description = "Map of cluster names to their node IAM role ARNs"
  value       = { for k, v in aws_iam_role.node_group : k => v.arn }
}

output "node_iam_role_names" {
  description = "Map of cluster names to their node IAM role names"
  value       = { for k, v in aws_iam_role.node_group : k => v.name }
}
