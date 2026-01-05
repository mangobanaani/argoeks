package tfpolicy

deny[msg] {
  input.resource_type == "aws_s3_bucket"
  input.values.acl == "public-read"
  msg := sprintf("Public S3 acl not allowed on %s", [input.address])
}

