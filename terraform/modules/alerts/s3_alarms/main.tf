locals {
  normalized = [for it in var.items : merge(it, {
    bucket = try(coalesce(it.bucket, element(split(":", it.bucket_arn), 5)), it.bucket)
  })]
  items = { for it in local.normalized : it.bucket => it }
}

resource "aws_s3_bucket_metric" "req" {
  for_each = var.enable_request_metrics ? local.items : {}
  bucket   = each.key
  name     = "EntireBucket"
}

resource "aws_cloudwatch_metric_alarm" "s3_5xx" {
  for_each            = local.items
  alarm_name          = "s3-${each.key}-5xx-errors"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = each.value.evals
  threshold           = each.value.five_xx_threshold
  metric_name         = "5xxErrors"
  namespace           = "AWS/S3"
  period              = each.value.period
  statistic           = "Sum"
  dimensions          = { BucketName = each.key, FilterId = "EntireBucket" }
  alarm_actions       = [var.sns_topic_arn]
  treat_missing_data  = "notBreaching"
}

resource "aws_cloudwatch_metric_alarm" "s3_4xx_rate" {
  for_each            = local.items
  alarm_name          = "s3-${each.key}-4xx-rate"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = each.value.evals
  threshold           = each.value.four_xx_rate_threshold_percent
  alarm_description   = "4xx error rate percentage"
  metric_query {
    id          = "m4xx"
    return_data = false
    metric {
      metric_name = "4xxErrors"
      namespace   = "AWS/S3"
      period      = each.value.period
      stat        = "Sum"
      dimensions  = { BucketName = each.key, FilterId = "EntireBucket" }
    }
  }
  metric_query {
    id          = "mreq"
    return_data = false
    metric {
      metric_name = "AllRequests"
      namespace   = "AWS/S3"
      period      = each.value.period
      stat        = "Sum"
      dimensions  = { BucketName = each.key, FilterId = "EntireBucket" }
    }
  }
  metric_query {
    id          = "e1"
    expression  = "100 * (m4xx / mreq)"
    label       = "4xxRatePercent"
    return_data = true
  }
  alarm_actions      = [var.sns_topic_arn]
  treat_missing_data = "notBreaching"
}
