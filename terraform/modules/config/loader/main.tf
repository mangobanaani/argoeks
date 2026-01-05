locals {
  cfg     = yamldecode(file(var.config_path))
  env_cfg = try(local.cfg.envs[var.environment], {})
}

output "env" { value = var.environment }
output "alerts" { value = try(local.env_cfg.alerts, {}) }
output "budgets" { value = try(local.env_cfg.budgets, {}) }
output "monitoring" { value = try(local.env_cfg.monitoring, {}) }
output "sns" { value = try(local.env_cfg.sns, {}) }
output "chatbot" { value = try(local.env_cfg.chatbot, {}) }
output "features" { value = try(local.env_cfg.features, {}) }
output "functions" { value = try(local.env_cfg.functions, []) }
output "edge" { value = try(local.env_cfg.edge, {}) }
