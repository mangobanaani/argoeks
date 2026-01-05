resource "aws_sns_topic" "alerts" {
  name = "${var.name_prefix}-alerts"
}

resource "aws_sns_topic_subscription" "email" {
  for_each  = toset(var.emails)
  topic_arn = aws_sns_topic.alerts.arn
  protocol  = "email"
  endpoint  = each.value
}

resource "aws_iam_role" "chatbot" {
  count = var.slack_workspace_id != "" && var.slack_channel_id != "" ? 1 : 0
  name  = "${var.name_prefix}-chatbot-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "chatbot.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "chatbot_readonly" {
  count      = var.slack_workspace_id != "" && var.slack_channel_id != "" ? 1 : 0
  role       = aws_iam_role.chatbot[0].name
  policy_arn = "arn:aws:iam::aws:policy/ReadOnlyAccess"
}

resource "aws_chatbot_slack_channel_configuration" "slack" {
  count                 = var.slack_workspace_id != "" && var.slack_channel_id != "" ? 1 : 0
  configuration_name    = "${var.name_prefix}-slack"
  slack_channel_id      = var.slack_channel_id
  slack_team_id         = var.slack_workspace_id
  iam_role_arn          = aws_iam_role.chatbot[0].arn
  sns_topic_arns        = [aws_sns_topic.alerts.arn]
  logging_level         = "ERROR"
  guardrail_policy_arns = []
}

resource "aws_sns_topic_policy" "allow_services" {
  arn = aws_sns_topic.alerts.arn
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Sid : "AllowCloudWatchPublish",
        Effect : "Allow",
        Principal : { Service : "cloudwatch.amazonaws.com" },
        Action : "sns:Publish",
        Resource : aws_sns_topic.alerts.arn
      },
      {
        Sid : "AllowBudgetsPublish",
        Effect : "Allow",
        Principal : { Service : "budgets.amazonaws.com" },
        Action : "sns:Publish",
        Resource : aws_sns_topic.alerts.arn
      },
      {
        Sid : "AllowEventBridgePublish",
        Effect : "Allow",
        Principal : { Service : "events.amazonaws.com" },
        Action : "sns:Publish",
        Resource : aws_sns_topic.alerts.arn
      }
    ]
  })
}

output "sns_topic_arn" { value = aws_sns_topic.alerts.arn }
