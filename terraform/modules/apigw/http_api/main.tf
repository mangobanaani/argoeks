resource "aws_cloudwatch_log_group" "access" {
  name              = "/aws/apigw/http/${var.name}"
  retention_in_days = 400
}

resource "aws_apigatewayv2_api" "this" {
  name          = var.name
  protocol_type = "HTTP"
  cors_configuration {
    allow_headers = var.cors_allowed_headers
    allow_methods = var.cors_allowed_methods
    allow_origins = var.cors_allowed_origins
  }
  tags = var.tags
}

resource "aws_apigatewayv2_integration" "lambda" {
  for_each               = { for r in var.routes : r.route_key => r }
  api_id                 = aws_apigatewayv2_api.this.id
  integration_type       = "AWS_PROXY"
  integration_uri        = each.value.lambda_arn
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_route" "routes" {
  for_each  = { for r in var.routes : r.route_key => r }
  api_id    = aws_apigatewayv2_api.this.id
  route_key = each.key
  target    = "integrations/${aws_apigatewayv2_integration.lambda[each.key].id}"
}

resource "aws_apigatewayv2_stage" "stage" {
  api_id      = aws_apigatewayv2_api.this.id
  name        = var.stage_name
  auto_deploy = true
  access_log_settings {
    destination_arn = aws_cloudwatch_log_group.access.arn
    format = jsonencode({
      requestId        = "$context.requestId",
      httpMethod       = "$context.httpMethod",
      path             = "$context.path",
      status           = "$context.status",
      ip               = "$context.identity.sourceIp",
      integrationError = "$context.integrationErrorMessage"
    })
  }
  tags = var.tags
}

resource "aws_lambda_permission" "api_invoke" {
  for_each      = { for r in var.routes : r.route_key => r }
  statement_id  = "AllowAPIGatewayInvoke-${replace(each.key, " ", "-")}"
  action        = "lambda:InvokeFunction"
  function_name = split(":", each.value.lambda_arn)[6]
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.this.execution_arn}/*/*"
}

output "api_id" { value = aws_apigatewayv2_api.this.id }
output "api_endpoint" { value = aws_apigatewayv2_api.this.api_endpoint }
output "stage_name" { value = aws_apigatewayv2_stage.stage.name }
output "stage_arn" { value = "arn:aws:apigateway:${data.aws_region.current.id}::/apis/${aws_apigatewayv2_api.this.id}/stages/${aws_apigatewayv2_stage.stage.name}" }

data "aws_region" "current" {}
