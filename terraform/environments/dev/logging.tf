module "vpc_flow_logs" {
  source         = "../../modules/logging/vpc_flow_logs"
  count          = var.enable_vpc_flow_logs ? 1 : 0
  vpc_id_map     = module.cluster_factory.vpc_ids
  retention_days = var.cw_vpc_flow_retention_days
}
