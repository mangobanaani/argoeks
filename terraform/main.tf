module "cluster_factory" {
  source         = "./modules/cluster_factory"
  region         = var.region
  cluster_count  = var.cluster_count
  cluster_config = var.cluster_config
}

output "cluster_names" {
  description = "All provisioned cluster names (first item is the management cluster)."
  value       = module.cluster_factory.cluster_names
}

