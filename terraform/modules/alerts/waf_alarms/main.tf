locals { items = { for it in var.items : it.acl_name => it } }

resource "aws_cloudwatch_metric_alarm" "waf_blocked" {
  for_each            = local.items
  alarm_name          = "waf-${each.key}-blocked"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = each.value.evals
  threshold           = each.value.blocked_threshold
  metric_name         = "BlockedRequests"
  namespace           = "AWS/WAFV2"
  period              = each.value.period
  statistic           = "Sum"
  dimensions          = { WebACL = each.key, Region = data.aws_region.current.id, Rule = "ALL" }
  alarm_actions       = [var.sns_topic_arn]
  treat_missing_data  = "notBreaching"
}

data "aws_region" "current" {}
