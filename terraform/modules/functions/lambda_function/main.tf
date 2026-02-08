data "aws_iam_policy_document" "assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {

      type = "Service"

      identifiers = ["lambda.amazonaws.com"]

    }
  }
}

resource "aws_iam_role" "exec" {
  name               = "lambda-${var.name}-exec"
  assume_role_policy = data.aws_iam_policy_document.assume.json
}

resource "aws_iam_role_policy_attachment" "basic" {
  role       = aws_iam_role.exec.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_policy" "extra" {
  count  = var.role_policy_json != null ? 1 : 0
  name   = "lambda-${var.name}-extra"
  policy = var.role_policy_json
}

resource "aws_iam_role_policy_attachment" "extra" {
  count      = var.role_policy_json != null ? 1 : 0
  role       = aws_iam_role.exec.name
  policy_arn = aws_iam_policy.extra[0].arn
}

resource "aws_cloudwatch_log_group" "lg" {
  name              = "/aws/lambda/${var.name}"
  retention_in_days = var.log_retention_days
}

resource "aws_lambda_function" "fn" {
  function_name    = var.name
  filename         = var.artifact_path
  source_code_hash = filebase64sha256(var.artifact_path)
  runtime          = var.runtime
  handler          = var.handler
  role             = aws_iam_role.exec.arn
  memory_size      = var.memory_size
  timeout          = var.timeout
  architectures    = var.architectures
  environment { variables = var.environment }
  dynamic "vpc_config" {
    for_each = length(var.vpc_subnet_ids) > 0 ? [1] : []
    content {
      subnet_ids         = var.vpc_subnet_ids
      security_group_ids = var.vpc_security_group_ids
    }
  }
}

resource "aws_apigatewayv2_api" "http" {
  count         = var.create_http_api ? 1 : 0
  name          = "${var.name}-http"
  protocol_type = "HTTP"
}

resource "aws_apigatewayv2_integration" "http" {
  count                  = var.create_http_api ? 1 : 0
  api_id                 = aws_apigatewayv2_api.http[0].id
  integration_type       = "AWS_PROXY"
  integration_uri        = aws_lambda_function.fn.arn
  payload_format_version = "2.0"
}

resource "aws_lambda_permission" "api" {
  count         = var.create_http_api ? 1 : 0
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.fn.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.http[0].execution_arn}/*/*"
}

resource "aws_apigatewayv2_route" "routes" {
  for_each  = var.create_http_api ? toset(var.http_routes) : []
  api_id    = aws_apigatewayv2_api.http[0].id
  route_key = each.key
  target    = "integrations/${aws_apigatewayv2_integration.http[0].id}"
}

resource "aws_apigatewayv2_stage" "default" {
  count       = var.create_http_api ? 1 : 0
  api_id      = aws_apigatewayv2_api.http[0].id
  name        = "$default"
  auto_deploy = true
  default_route_settings {

    throttling_burst_limit = 500

    throttling_rate_limit = 1000

  }
}

output "function_arn" { value = aws_lambda_function.fn.arn }
output "invoke_arn" { value = aws_lambda_function.fn.invoke_arn }
output "url" { value = var.create_http_api ? aws_apigatewayv2_api.http[0].api_endpoint : null }
