terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
    }
  }
}

resource "aws_budgets_budget" "monthly" {
  name         = var.name
  budget_type  = "COST"
  limit_amount = tostring(var.limit_amount)
  limit_unit   = var.limit_unit
  time_unit    = "MONTHLY"

  dynamic "notification" {
    for_each = toset(var.thresholds)
    content {
      comparison_operator        = "GREATER_THAN"
      threshold                  = notification.value
      threshold_type             = "PERCENTAGE"
      notification_type          = "ACTUAL"
      subscriber_email_addresses = var.emails
      subscriber_sns_topic_arns  = var.sns_topic_arn != "" ? [var.sns_topic_arn] : []
    }
  }
}
