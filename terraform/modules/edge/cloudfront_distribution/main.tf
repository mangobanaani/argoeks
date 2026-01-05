locals {
  default_behavior = one([for b in var.behaviors : b if try(b.is_default, false)])
}

resource "aws_cloudfront_distribution" "this" {
  enabled             = var.enabled
  comment             = var.comment
  aliases             = var.aliases
  default_root_object = var.default_root_object != "" ? var.default_root_object : null

  dynamic "origin" {
    for_each = { for o in var.origins : o.id => o }
    content {
      domain_name = origin.value.domain_name
      origin_id   = origin.key
      origin_path = try(origin.value.origin_path, null)
      dynamic "s3_origin_config" {
        for_each = try(origin.value.type, "") == "s3" ? [1] : []
        content { origin_access_identity = null }
      }
      dynamic "custom_origin_config" {
        for_each = try(origin.value.type, "") != "s3" ? [1] : []
        content {
          http_port              = 80
          https_port             = 443
          origin_protocol_policy = try(origin.value.protocol_policy, "https-only")
          origin_ssl_protocols   = ["TLSv1.2"]
        }
      }
    }
  }

  default_cache_behavior {
    target_origin_id         = local.default_behavior.origin_id
    viewer_protocol_policy   = local.default_behavior.viewer_protocol_policy
    allowed_methods          = local.default_behavior.allowed_methods
    cached_methods           = local.default_behavior.cached_methods
    compress                 = try(local.default_behavior.compress, true)
    cache_policy_id          = try(local.default_behavior.cache_policy_id, null)
    origin_request_policy_id = try(local.default_behavior.origin_request_policy_id, null)
    dynamic "function_association" {
      for_each = try(local.default_behavior.function_associations, [])
      content {
        event_type   = function_association.value.event_type
        function_arn = function_association.value.function_arn
      }
    }
  }

  dynamic "ordered_cache_behavior" {
    for_each = [for b in var.behaviors : b if !try(b.is_default, false)]
    content {
      path_pattern             = ordered_cache_behavior.value.path_pattern
      target_origin_id         = ordered_cache_behavior.value.origin_id
      viewer_protocol_policy   = ordered_cache_behavior.value.viewer_protocol_policy
      allowed_methods          = ordered_cache_behavior.value.allowed_methods
      cached_methods           = ordered_cache_behavior.value.cached_methods
      compress                 = try(ordered_cache_behavior.value.compress, true)
      cache_policy_id          = try(ordered_cache_behavior.value.cache_policy_id, null)
      origin_request_policy_id = try(ordered_cache_behavior.value.origin_request_policy_id, null)
      dynamic "function_association" {
        for_each = try(ordered_cache_behavior.value.function_associations, [])
        content {
          event_type   = function_association.value.event_type
          function_arn = function_association.value.function_arn
        }
      }
    }
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    acm_certificate_arn      = var.acm_cert_arn
    ssl_support_method       = "sni-only"
    minimum_protocol_version = "TLSv1.2_2021"
  }

  price_class = var.price_class
}

resource "aws_wafv2_web_acl_association" "waf" {
  count        = var.wafv2_acl_arn != "" ? 1 : 0
  resource_arn = aws_cloudfront_distribution.this.arn
  web_acl_arn  = var.wafv2_acl_arn
}

output "distribution_id" { value = aws_cloudfront_distribution.this.id }
output "domain_name" { value = aws_cloudfront_distribution.this.domain_name }
