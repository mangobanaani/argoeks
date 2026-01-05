locals { items = { for it in var.items : it.service => it } }

data "aws_lb" "by_name" {
  for_each = { for k, v in local.items : k => v if try(v.lb_name, null) != null }
  name     = each.value.lb_name
}

data "aws_lb_target_group" "by_name" {
  for_each = { for k, v in local.items : k => v if try(v.tg_name, null) != null }
  name     = each.value.tg_name
}

resource "aws_cloudwatch_metric_alarm" "healthy" {
  for_each            = local.items
  alarm_name          = "${each.key}-tg-healthy-hosts"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = each.value.evals
  threshold           = each.value.healthy_min
  metric_name         = "HealthyHostCount"
  namespace           = "AWS/ApplicationELB"
  period              = each.value.period
  statistic           = "Average"
  dimensions = {
    TargetGroup  = coalesce(try(each.value.tg_full_name, null), try(data.aws_lb_target_group.by_name[each.key].arn_suffix, null))
    LoadBalancer = coalesce(try(each.value.lb_full_name, null), try(data.aws_lb.by_name[each.key].arn_suffix, null))
  }
  alarm_actions      = [var.sns_topic_arn]
  treat_missing_data = "breaching"
}

resource "aws_cloudwatch_metric_alarm" "unhealthy" {
  for_each            = local.items
  alarm_name          = "${each.key}-tg-unhealthy-hosts"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = each.value.evals
  threshold           = each.value.unhealthy_max
  metric_name         = "UnHealthyHostCount"
  namespace           = "AWS/ApplicationELB"
  period              = each.value.period
  statistic           = "Average"
  dimensions = {
    TargetGroup  = coalesce(try(each.value.tg_full_name, null), try(data.aws_lb_target_group.by_name[each.key].arn_suffix, null))
    LoadBalancer = coalesce(try(each.value.lb_full_name, null), try(data.aws_lb.by_name[each.key].arn_suffix, null))
  }
  alarm_actions      = [var.sns_topic_arn]
  treat_missing_data = "breaching"
}
