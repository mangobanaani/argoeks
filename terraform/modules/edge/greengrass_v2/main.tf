resource "aws_iot_thing_group" "group" {
  name = var.thing_group_name
  tags = var.tags
}

resource "aws_iam_role" "token_exchange" {
  count = var.create_token_exchange_role ? 1 : 0
  name  = "GreengrassV2TokenExchangeRole"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect    = "Allow",
      Action    = "sts:AssumeRole",
      Principal = { Service = "credentials.iot.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "token_exchange_access" {
  count      = var.create_token_exchange_role ? 1 : 0
  role       = aws_iam_role.token_exchange[0].name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSGreengrassV2TokenExchangeRoleAccess"
}

resource "aws_iot_role_alias" "alias" {
  count               = var.create_token_exchange_role ? 1 : 0
  alias               = "GreengrassV2TokenExchangeRoleAlias"
  role_arn            = aws_iam_role.token_exchange[0].arn
  credential_duration = 3600
}

output "thing_group_arn" { value = aws_iot_thing_group.group.arn }
output "role_alias" { value = try(aws_iot_role_alias.alias[0].alias, null) }
