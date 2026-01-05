locals { items = { for it in var.items : it.replication_group_id => it } }

resource "aws_cloudwatch_metric_alarm" "cpu" {
  for_each            = local.items
  alarm_name          = "redis-${each.key}-cpu-high"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = each.value.evals
  threshold           = each.value.cpu_high_threshold
  metric_name         = "CPUUtilization"
  namespace           = "AWS/ElastiCache"
  period              = each.value.period
  statistic           = "Average"
  dimensions          = { ReplicationGroupId = each.key }
  alarm_actions       = [var.sns_topic_arn]
  treat_missing_data  = "notBreaching"
}

resource "aws_cloudwatch_metric_alarm" "free_memory" {
  for_each            = local.items
  alarm_name          = "redis-${each.key}-freeable-memory-low"
  comparison_operator = "LessThanOrEqualToThreshold"
  evaluation_periods  = each.value.evals
  threshold           = each.value.freeable_memory_low_mb * 1024 * 1024
  metric_name         = "FreeableMemory"
  namespace           = "AWS/ElastiCache"
  period              = each.value.period
  statistic           = "Average"
  dimensions          = { ReplicationGroupId = each.key }
  alarm_actions       = [var.sns_topic_arn]
  treat_missing_data  = "breaching"
}

resource "aws_cloudwatch_metric_alarm" "evictions" {
  for_each            = local.items
  alarm_name          = "redis-${each.key}-evictions"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = each.value.evals
  threshold           = each.value.evictions_threshold
  metric_name         = "Evictions"
  namespace           = "AWS/ElastiCache"
  period              = each.value.period
  statistic           = "Sum"
  dimensions          = { ReplicationGroupId = each.key }
  alarm_actions       = [var.sns_topic_arn]
  treat_missing_data  = "notBreaching"
}

