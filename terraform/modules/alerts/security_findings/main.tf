resource "aws_cloudwatch_event_rule" "security_hub" {
  count = var.enable_security_hub ? 1 : 0
  name  = "securityhub-high-critical-findings"
  event_pattern = jsonencode({
    source      = ["aws.securityhub"],
    detail_type = ["Security Hub Findings - Imported"],
    detail = {
      findings = {
        Severity    = { Label = var.security_hub_severities }
        RecordState = ["ACTIVE"]
      }
    }
  })
}

resource "aws_cloudwatch_event_rule" "guardduty" {
  count = var.enable_guardduty ? 1 : 0
  name  = "guardduty-high-severity-findings"
  event_pattern = jsonencode({
    source      = ["aws.guardduty"],
    detail_type = ["GuardDuty Finding"],
    detail = {
      severity = [{ numeric = [">=", var.guardduty_min_severity] }]
    }
  })
}

resource "aws_cloudwatch_event_target" "security_hub_sns" {
  count     = var.enable_security_hub ? 1 : 0
  rule      = aws_cloudwatch_event_rule.security_hub[0].name
  target_id = "sns"
  arn       = var.sns_topic_arn
}

resource "aws_cloudwatch_event_target" "guardduty_sns" {
  count     = var.enable_guardduty ? 1 : 0
  rule      = aws_cloudwatch_event_rule.guardduty[0].name
  target_id = "sns"
  arn       = var.sns_topic_arn
}

