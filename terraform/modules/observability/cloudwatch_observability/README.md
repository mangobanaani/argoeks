# aws_cloudwatch_observability

Installs the Amazon CloudWatch Observability EKS add-on, enabling Container Insights and Application Signals. It creates the IAM role with `CloudWatchAgentServerPolicy` and associates it with the add-on via `aws_eks_addon`.

## Inputs
- `enabled` (bool) – gate the module (default true).
- `cluster_name` – EKS cluster name.
- `role_name` – IAM role name to create for the add-on.
- `addon_version` – optional pinned version (`null` picks the latest).
- `tags` – map applied to IAM role/add-on.

## Outputs
- `role_arn` – IAM role ARN used by the add-on.

## Usage
```hcl
module "cloudwatch_observability" {
  source       = "../../modules/observability/cloudwatch_observability"
  count        = var.enable_cloudwatch_observability ? 1 : 0
  cluster_name = module.cluster_factory.cluster_names[0]
  role_name    = "dev-cloudwatch-observability"
  addon_version = var.cloudwatch_observability_addon_version
  tags         = { environment = "dev" }
}
```
