provider "aws" {
  alias  = "use1"
  region = "us-east-1"
}

resource "aws_cloudfront_function" "this" {
  provider = aws.use1
  name     = var.name
  runtime  = "cloudfront-js-1.0"
  comment  = var.comment
  publish  = true
  code     = file(var.code_path)
}

output "arn" { value = aws_cloudfront_function.this.arn }
output "etag" { value = aws_cloudfront_function.this.etag }
