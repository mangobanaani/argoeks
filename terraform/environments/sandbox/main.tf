module "cluster_factory" {
  source         = "../../modules/cluster_factory"
  region         = var.region
  cluster_count  = var.cluster_count
  cluster_config = var.cluster_config
  name_prefix    = var.name_prefix
  environment    = "sandbox"
  base_cidr      = "10.192.0.0/8"
}

output "cluster_names" { value = module.cluster_factory.cluster_names }

variable "enable_cilium" {

  type = bool

  default = false

}

module "cilium" {
  source       = "../../modules/networking/cilium"
  install      = var.enable_cilium
  cluster_name = module.cluster_factory.cluster_names[0]
  providers = {
    kubernetes = kubernetes.hub
    helm       = helm.hub
  }
}
