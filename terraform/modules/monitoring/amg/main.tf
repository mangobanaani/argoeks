resource "aws_grafana_workspace" "this" {
  account_access_type      = var.account_access_type
  authentication_providers = var.authentication_providers
  permission_type          = var.permission_type
  tags                     = var.tags
}

output "workspace_id" { value = aws_grafana_workspace.this.id }
output "endpoint" { value = aws_grafana_workspace.this.endpoint }
