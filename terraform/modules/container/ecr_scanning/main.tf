resource "aws_ecr_registry_scanning_configuration" "this" {
  scan_type = var.scan_type
  rule {
    scan_frequency = var.rules[0].scan_frequency
    repository_filter {
      filter      = var.rules[0].filter
      filter_type = "WILDCARD"
    }
  }
}

