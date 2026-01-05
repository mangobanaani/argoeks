terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
    }
  }
}

resource "aws_cloudwatch_metric_alarm" "billing" {
  alarm_name          = var.name
  alarm_description   = "Estimated AWS charges exceeded"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 1
  threshold           = var.threshold
  metric_name         = "EstimatedCharges"
  namespace           = "AWS/Billing"
  statistic           = "Maximum"
  period              = 21600
  dimensions          = { Currency = var.currency }
  alarm_actions       = [var.sns_topic_arn]
}
