resource "aws_cloudwatch_log_group" "vpc" {
  name              = var.log_group_name
  retention_in_days = var.retention_days
}

resource "aws_iam_role" "flow" {
  name = "vpc-flow-logs-to-cw"
  assume_role_policy = jsonencode({
    Version   = "2012-10-17",
    Statement = [{ Effect = "Allow", Principal = { Service = "vpc-flow-logs.amazonaws.com" }, Action = "sts:AssumeRole" }]
  })
}

resource "aws_iam_role_policy" "flow" {
  role = aws_iam_role.flow.id
  policy = jsonencode({
    Version   = "2012-10-17",
    Statement = [{ Effect = "Allow", Action = ["logs:CreateLogStream", "logs:PutLogEvents"], Resource = "${aws_cloudwatch_log_group.vpc.arn}:*" }]
  })
}

resource "aws_flow_log" "this" {
  for_each             = var.vpc_id_map
  vpc_id               = each.value
  log_destination      = aws_cloudwatch_log_group.vpc.arn
  iam_role_arn         = aws_iam_role.flow.arn
  traffic_type         = "ALL"
  log_destination_type = "cloud-watch-logs"
}
