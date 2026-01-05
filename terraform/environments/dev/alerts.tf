module "notifications" {
  source             = "../../modules/alerts/notifications"
  name_prefix        = "dev"
  emails             = try(module.config.alerts.emails, [])
  slack_workspace_id = try(module.config.alerts.slack.workspace_id, "")
  slack_channel_id   = try(module.config.alerts.slack.channel_id, "")
}

module "budgets" {
  source        = "../../modules/alerts/budgets"
  name          = "dev-monthly"
  limit_amount  = try(module.config.budgets.amount, 500)
  limit_unit    = try(module.config.budgets.currency, "USD")
  thresholds    = try(module.config.budgets.thresholds, [80, 95, 100])
  emails        = try(module.config.alerts.emails, [])
  sns_topic_arn = module.notifications.sns_topic_arn
}

module "billing_alarm" {
  source        = "../../modules/alerts/cloudwatch_billing"
  providers     = { aws = aws.billing }
  name          = "dev-billing"
  currency      = try(module.config.budgets.currency, "USD")
  threshold     = try(module.config.budgets.billing_alarm_threshold, 400)
  sns_topic_arn = module.notifications.sns_topic_arn
}

module "alb_alarms" {
  count         = (var.enable_alb_alarms || try(module.config.features.observability.alb_alarms, false)) ? 1 : 0
  source        = "../../modules/alerts/alb_alarms"
  name_prefix   = "dev"
  sns_topic_arn = module.notifications.sns_topic_arn
  items         = try(module.config.monitoring.alb_alarms, [])
}

module "tg_alarms" {
  count         = (var.enable_tg_alarms || try(module.config.features.observability.tg_alarms, false)) ? 1 : 0
  source        = "../../modules/alerts/target_group_alarms"
  sns_topic_arn = module.notifications.sns_topic_arn
  items         = try(module.config.monitoring.target_group_alarms, [])
}

module "s3_alarms" {
  count         = (var.enable_s3_alarms || try(module.config.features.observability.s3_alarms, false)) ? 1 : 0
  source        = "../../modules/alerts/s3_alarms"
  sns_topic_arn = module.notifications.sns_topic_arn
  items         = try(module.config.monitoring.s3_alarms, [])
}

module "security_findings" {
  count         = var.enable_security_findings ? 1 : 0
  source        = "../../modules/alerts/security_findings"
  sns_topic_arn = module.notifications.sns_topic_arn
}

module "rds_alarms" {
  source        = "../../modules/alerts/rds_alarms"
  sns_topic_arn = module.notifications.sns_topic_arn
  items = concat(
    var.enable_rds_postgres ? [{
      instance_id            = "dev-mlops-postgres"
      period                 = local.rds_alarm_defaults.period
      evals                  = local.rds_alarm_defaults.evals
      cpu_high_threshold     = local.rds_alarm_defaults.cpu_high_threshold
      free_storage_low_mb    = local.rds_alarm_defaults.free_storage_low_mb
      freeable_memory_low_mb = local.rds_alarm_defaults.freeable_memory_low_mb
      read_latency_sec       = local.rds_alarm_defaults.read_latency_sec
      write_latency_sec      = local.rds_alarm_defaults.write_latency_sec
      connections_high       = local.rds_alarm_defaults.connections_high
    }] : [],
    (var.enable_aurora && length(module.aurora) > 0) ? [for id in module.aurora[0].instance_ids : {
      instance_id            = id
      period                 = local.rds_alarm_defaults.period
      evals                  = local.rds_alarm_defaults.evals
      cpu_high_threshold     = local.rds_alarm_defaults.cpu_high_threshold
      free_storage_low_mb    = local.rds_alarm_defaults.free_storage_low_mb
      freeable_memory_low_mb = local.rds_alarm_defaults.freeable_memory_low_mb
      read_latency_sec       = local.rds_alarm_defaults.read_latency_sec
      write_latency_sec      = local.rds_alarm_defaults.write_latency_sec
      connections_high       = local.rds_alarm_defaults.connections_high
    }] : []
  )
}


module "redis_alarms" {
  source        = "../../modules/alerts/redis_alarms"
  sns_topic_arn = module.notifications.sns_topic_arn
  items = var.enable_redis ? [{
    replication_group_id   = "dev-mlops-redis"
    period                 = local.redis_alarm_defaults.period
    evals                  = local.redis_alarm_defaults.evals
    cpu_high_threshold     = local.redis_alarm_defaults.cpu_high_threshold
    freeable_memory_low_mb = local.redis_alarm_defaults.freeable_memory_low_mb
    evictions_threshold    = local.redis_alarm_defaults.evictions_threshold
  }] : []
}

module "waf_alarms" {
  source        = "../../modules/alerts/waf_alarms"
  sns_topic_arn = module.notifications.sns_topic_arn
  items         = try(module.config.monitoring.waf_alarms, [{ acl_name = "dev-argocd-waf", blocked_threshold = 100, period = 300, evals = 1 }])
}
