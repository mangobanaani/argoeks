resource "aws_api_gateway_rest_api" "this" {
  name = var.name
  body = file(var.openapi_path)
  tags = var.tags
}

resource "aws_api_gateway_deployment" "this" {
  rest_api_id = aws_api_gateway_rest_api.this.id
  triggers    = { redeploy = filebase64sha256(var.openapi_path) }
  lifecycle { create_before_destroy = true }
}

resource "aws_cloudwatch_log_group" "access" {
  name              = "/aws/apigw/rest/${var.name}"
  retention_in_days = 400
}

resource "aws_api_gateway_stage" "stage" {
  rest_api_id   = aws_api_gateway_rest_api.this.id
  deployment_id = aws_api_gateway_deployment.this.id
  stage_name    = var.stage_name
  access_log_settings {
    destination_arn = aws_cloudwatch_log_group.access.arn
    format = jsonencode({
      requestId  = "$context.requestId",
      httpMethod = "$context.httpMethod",
      path       = "$context.path",
      status     = "$context.status",
      ip         = "$context.identity.sourceIp"
    })
  }
  tags = var.tags
}

resource "aws_wafv2_web_acl_association" "assoc" {
  count        = var.wafv2_acl_arn != "" ? 1 : 0
  resource_arn = "arn:aws:apigateway:${var.region}::/restapis/${aws_api_gateway_rest_api.this.id}/stages/${aws_api_gateway_stage.stage.stage_name}"
  web_acl_arn  = var.wafv2_acl_arn
}

output "rest_api_id" { value = aws_api_gateway_rest_api.this.id }
output "invoke_url" { value = aws_api_gateway_stage.stage.invoke_url }
output "stage_arn" { value = "arn:aws:apigateway:${var.region}::/restapis/${aws_api_gateway_rest_api.this.id}/stages/${aws_api_gateway_stage.stage.stage_name}" }
