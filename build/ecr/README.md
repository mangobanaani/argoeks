# Shared ECR Registry

Cross-account Amazon Elastic Container Registry for storing container images used across all environments.

## Features

- KMS encryption for images
- Automatic vulnerability scanning on push
- Cross-account access policy
- Lifecycle policies (auto-expire old images)
- Immutable tags support

## Usage

### Single Account

```hcl
module "shared_ecr" {
  source = "./build/ecr"

  name                 = "mlops/python-base"
  image_tag_mutability = "IMMUTABLE"  # Prevent tag overwrite
  scan_on_push         = true

  tags = {
    Purpose     = "Shared Base Images"
    ManagedBy   = "Terraform"
    Environment = "shared"
  }
}
```

### Cross-Account Access

```hcl
module "shared_ecr" {
  source = "./build/ecr"

  name = "mlops/python-base"

  # Allow dev and prod accounts to pull
  allowed_account_ids = [
    "111111111111",  # dev account
    "222222222222",  # prod account
  ]

  tags = {
    Purpose = "Cross-Account Shared Registry"
  }
}
```

### Custom Lifecycle Policy

```hcl
module "shared_ecr" {
  source = "./build/ecr"

  name = "mlops/training-image"

  lifecycle_policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Keep last 30 production images"
        selection = {
          tagStatus     = "tagged"
          tagPrefixList = ["prod-"]
          countType     = "imageCountMoreThan"
          countNumber   = 30
        }
        action = {
          type = "expire"
        }
      }
    ]
  })
}
```

## Default Lifecycle Policy

If no custom policy is provided, the module uses:

- Keep last 10 tagged images (prefix: `v*`, `release*`)
- Expire untagged images after 14 days

## Outputs

- `repository_url` - Full URL for docker push/pull

## Example: Pull from Another Account

In the consuming account, grant ECR permissions to your EKS node role or pod IRSA role:

```hcl
data "aws_iam_policy_document" "ecr_pull" {
  statement {
    actions = [
      "ecr:GetAuthorizationToken",
      "ecr:BatchCheckLayerAvailability",
      "ecr:GetDownloadUrlForLayer",
      "ecr:BatchGetImage"
    ]
    resources = ["arn:aws:ecr:us-east-1:123456789012:repository/mlops/*"]
  }
}
```

Then pull images:

```bash
# Authenticate
aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin 123456789012.dkr.ecr.us-east-1.amazonaws.com

# Pull
docker pull 123456789012.dkr.ecr.us-east-1.amazonaws.com/mlops/python-base:v1.0.0
```

## Security Best Practices

1. Use `IMMUTABLE` tags for production images
2. Enable `scan_on_push` for vulnerability detection
3. Limit cross-account access to specific accounts
4. Use KMS encryption (automatic with this module)
5. Implement signing/verification workflow

## Cost Optimization

- Lifecycle policies automatically clean up old images
- Cross-account sharing reduces duplicate storage
- Scan only on push (not on pull)

## Monitoring

Monitor ECR metrics in CloudWatch:
- `RepositoryPullCount` - Track image pull frequency
- `RepositoryImageScanOnPush` - Vulnerability scan results
