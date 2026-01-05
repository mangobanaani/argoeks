resource "aws_wafv2_web_acl" "this" {
  name        = var.name
  description = "Bank-grade baseline WAF ACL"
  scope       = var.scope

  default_action {
    allow {}
  }

  dynamic "rule" {
    for_each = var.managed_rule_groups
    content {
      name     = rule.value.name
      priority = rule.value.priority
      override_action {
        none {}
      }
      statement {
        managed_rule_group_statement {
          name        = rule.value.name
          vendor_name = rule.value.vendor
        }
      }
      visibility_config {
        cloudwatch_metrics_enabled = true
        metric_name                = "${var.name}-${rule.value.name}"
        sampled_requests_enabled   = true
      }
    }
  }

  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = var.name
    sampled_requests_enabled   = true
  }

  # Add response headers for TLS security policies on blocked responses
  custom_response_body {
    key          = "default"
    content_type = "TEXT_HTML"
    content      = "<html><body>Request blocked.</body></html>"
  }

  tags = var.tags
}

output "arn" { value = aws_wafv2_web_acl.this.arn }
