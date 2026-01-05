output "trail_arn" {
  value       = aws_cloudtrail.org.arn
  description = "ARN of the organization trail."
}

output "trail_bucket_name" {
  value       = local.trail_bucket_name
  description = "CloudTrail log bucket name."
}
