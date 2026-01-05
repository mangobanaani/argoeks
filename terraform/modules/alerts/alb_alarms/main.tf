locals { items = { for it in var.items : it.service => it } }

data "aws_lb" "by_name" {
  for_each = { for k, v in local.items : k => v if try(v.lb_name, null) != null }
  name     = each.value.lb_name
}

data "external" "lb_by_tags" {
  for_each = { for k, v in local.items : k => v if try(v.lb_tags, null) != null }
  program  = ["bash", "${path.module}/../../../scripts/discover-alb.sh", data.aws_region.current.id, jsonencode(each.value.lb_tags)]
}

data "aws_region" "current" {}

resource "aws_cloudwatch_metric_alarm" "elb_5xx" {
  for_each            = local.items
  alarm_name          = "${var.name_prefix}-${each.key}-alb-elb-5xx"
  alarm_description   = "${each.key}: ALB 5XX from ELB"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = each.value.elb_5xx_evals
  threshold           = each.value.elb_5xx_threshold
  metric_name         = "HTTPCode_ELB_5XX_Count"
  namespace           = "AWS/ApplicationELB"
  period              = each.value.elb_5xx_period
  statistic           = "Sum"
  dimensions = {
    LoadBalancer = coalesce(try(each.value.lb_full_name, null), try(data.aws_lb.by_name[each.key].arn_suffix, null), try(data.external.lb_by_tags[each.key].result.arn_suffix, null))
  }
  treat_missing_data = "notBreaching"
  alarm_actions      = [var.sns_topic_arn]
}

resource "aws_cloudwatch_metric_alarm" "target_5xx" {
  for_each            = local.items
  alarm_name          = "${var.name_prefix}-${each.key}-alb-target-5xx"
  alarm_description   = "${each.key}: Target 5XX"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = try(each.value.target_5xx_evals, 3)
  threshold           = try(each.value.target_5xx_threshold, 100)
  metric_name         = "HTTPCode_Target_5XX_Count"
  namespace           = "AWS/ApplicationELB"
  period              = try(each.value.target_5xx_period, 60)
  statistic           = "Sum"
  dimensions = {
    LoadBalancer = coalesce(try(each.value.lb_full_name, null), try(data.aws_lb.by_name[each.key].arn_suffix, null), try(data.external.lb_by_tags[each.key].result.arn_suffix, null))
  }
  treat_missing_data = "notBreaching"
  alarm_actions      = [var.sns_topic_arn]
}

resource "aws_cloudwatch_metric_alarm" "latency" {
  for_each            = local.items
  alarm_name          = "${var.name_prefix}-${each.key}-alb-latency"
  alarm_description   = "${each.key}: ALB TargetResponseTime ${each.value.latency_stat}"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = each.value.latency_evals
  threshold           = each.value.latency_threshold
  metric_name         = "TargetResponseTime"
  namespace           = "AWS/ApplicationELB"
  period              = each.value.latency_period
  dimensions = {
    LoadBalancer = coalesce(try(each.value.lb_full_name, null), try(data.aws_lb.by_name[each.key].arn_suffix, null), try(data.external.lb_by_tags[each.key].result.arn_suffix, null))
  }
  treat_missing_data = "notBreaching"
  alarm_actions      = [var.sns_topic_arn]
  extended_statistic = startswith(lower(each.value.latency_stat), "p") ? each.value.latency_stat : null
  statistic          = startswith(lower(each.value.latency_stat), "p") ? null : each.value.latency_stat
}
