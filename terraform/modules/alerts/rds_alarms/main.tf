locals { items = var.items }

resource "aws_cloudwatch_metric_alarm" "cpu" {
  for_each            = { for it in local.items : it.instance_id => it }
  alarm_name          = "rds-${each.key}-cpu-high"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = each.value.evals
  threshold           = each.value.cpu_high_threshold
  metric_name         = "CPUUtilization"
  namespace           = "AWS/RDS"
  period              = each.value.period
  statistic           = "Average"
  dimensions          = { DBInstanceIdentifier = each.key }
  alarm_actions       = [var.sns_topic_arn]
  treat_missing_data  = "notBreaching"
}

resource "aws_cloudwatch_metric_alarm" "free_storage" {
  for_each            = { for it in local.items : it.instance_id => it }
  alarm_name          = "rds-${each.key}-free-storage-low"
  comparison_operator = "LessThanOrEqualToThreshold"
  evaluation_periods  = each.value.evals
  threshold           = each.value.free_storage_low_mb * 1024 * 1024
  metric_name         = "FreeStorageSpace"
  namespace           = "AWS/RDS"
  period              = each.value.period
  statistic           = "Average"
  dimensions          = { DBInstanceIdentifier = each.key }
  alarm_actions       = [var.sns_topic_arn]
  treat_missing_data  = "breaching"
}

resource "aws_cloudwatch_metric_alarm" "free_memory" {
  for_each            = { for it in local.items : it.instance_id => it }
  alarm_name          = "rds-${each.key}-freeable-memory-low"
  comparison_operator = "LessThanOrEqualToThreshold"
  evaluation_periods  = each.value.evals
  threshold           = each.value.freeable_memory_low_mb * 1024 * 1024
  metric_name         = "FreeableMemory"
  namespace           = "AWS/RDS"
  period              = each.value.period
  statistic           = "Average"
  dimensions          = { DBInstanceIdentifier = each.key }
  alarm_actions       = [var.sns_topic_arn]
  treat_missing_data  = "breaching"
}

resource "aws_cloudwatch_metric_alarm" "read_latency" {
  for_each            = { for it in local.items : it.instance_id => it }
  alarm_name          = "rds-${each.key}-read-latency"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = each.value.evals
  threshold           = each.value.read_latency_sec
  metric_name         = "ReadLatency"
  namespace           = "AWS/RDS"
  period              = each.value.period
  statistic           = "Average"
  dimensions          = { DBInstanceIdentifier = each.key }
  alarm_actions       = [var.sns_topic_arn]
  treat_missing_data  = "notBreaching"
}

resource "aws_cloudwatch_metric_alarm" "write_latency" {
  for_each            = { for it in local.items : it.instance_id => it }
  alarm_name          = "rds-${each.key}-write-latency"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = each.value.evals
  threshold           = each.value.write_latency_sec
  metric_name         = "WriteLatency"
  namespace           = "AWS/RDS"
  period              = each.value.period
  statistic           = "Average"
  dimensions          = { DBInstanceIdentifier = each.key }
  alarm_actions       = [var.sns_topic_arn]
  treat_missing_data  = "notBreaching"
}

resource "aws_cloudwatch_metric_alarm" "connections" {
  for_each            = { for it in local.items : it.instance_id => it }
  alarm_name          = "rds-${each.key}-connections-high"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = each.value.evals
  threshold           = each.value.connections_high
  metric_name         = "DatabaseConnections"
  namespace           = "AWS/RDS"
  period              = each.value.period
  statistic           = "Average"
  dimensions          = { DBInstanceIdentifier = each.key }
  alarm_actions       = [var.sns_topic_arn]
  treat_missing_data  = "notBreaching"
}

