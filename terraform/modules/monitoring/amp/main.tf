resource "aws_prometheus_workspace" "this" {
  alias = var.alias
  tags  = var.tags
}

output "workspace_id" { value = aws_prometheus_workspace.this.id }
output "prometheus_endpoint" { value = aws_prometheus_workspace.this.prometheus_endpoint }
