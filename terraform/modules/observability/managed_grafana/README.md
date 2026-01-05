# Amazon Managed Grafana Module

Provisions Amazon Managed Grafana workspace for SLO/SLI visualization and observability dashboards.

## Overview

This module creates a fully-managed Grafana workspace with:
- AWS SSO or SAML authentication
- Built-in data source support (Prometheus, CloudWatch, X-Ray)
- Unified alerting capabilities
- Optional API key for automation
- IAM role for cross-service access

## Features

- Fully-managed Grafana service (no cluster overhead)
- AWS SSO integration for authentication
- Pre-configured data sources: Amazon Managed Prometheus (AMP), CloudWatch, X-Ray
- Unified alerting with SNS notification support
- Plugin administration enabled
- API key creation for programmatic access (optional)
- Secrets Manager integration for API key storage

## Usage

### Basic Configuration (AWS SSO)

```hcl
module "managed_grafana" {
  source = "../../modules/observability/managed_grafana"

  environment                = "prod"
  account_access_type        = "CURRENT_ACCOUNT"
  authentication_providers   = ["AWS_SSO"]
  permission_type            = "SERVICE_MANAGED"
  data_sources               = ["PROMETHEUS", "CLOUDWATCH", "XRAY"]
  notification_destinations  = ["SNS"]

  create_iam_role = true
  create_api_key  = false

  tags = {
    cluster     = "prod-cluster-01"
    environment = "prod"
    purpose     = "slo-monitoring"
  }
}
```

### Multi-Account Organization Access

```hcl
module "managed_grafana" {
  source = "../../modules/observability/managed_grafana"

  environment                = "prod"
  account_access_type        = "ORGANIZATION"
  authentication_providers   = ["AWS_SSO"]
  permission_type            = "SERVICE_MANAGED"

  organization_role_name     = "GrafanaDataSourceRole"
  organizational_units       = ["ou-abc-12345678"]

  data_sources               = ["PROMETHEUS", "CLOUDWATCH", "XRAY"]
  notification_destinations  = ["SNS"]

  create_iam_role = true

  tags = {
    environment = "prod"
    purpose     = "multi-account-monitoring"
  }
}
```

### With API Key for Automation

```hcl
module "managed_grafana" {
  source = "../../modules/observability/managed_grafana"

  environment                = "dev"
  authentication_providers   = ["AWS_SSO"]

  create_iam_role = true
  create_api_key  = true
  api_key_ttl     = 2592000  # 30 days

  tags = {
    cluster     = "dev-cluster-01"
    environment = "dev"
  }
}
```

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|----------|
| enabled | Enable Amazon Managed Grafana workspace | bool | true | no |
| environment | Environment name (dev, qa, prod) | string | - | yes |
| account_access_type | Account access type (CURRENT_ACCOUNT or ORGANIZATION) | string | "CURRENT_ACCOUNT" | no |
| authentication_providers | Authentication providers (AWS_SSO, SAML) | list(string) | ["AWS_SSO"] | no |
| permission_type | Permission type (CUSTOMER_MANAGED or SERVICE_MANAGED) | string | "SERVICE_MANAGED" | no |
| data_sources | Data sources to enable | list(string) | ["PROMETHEUS", "CLOUDWATCH", "XRAY"] | no |
| notification_destinations | Notification destinations | list(string) | ["SNS"] | no |
| organization_role_name | IAM role name in organization accounts | string | "" | no |
| organizational_units | AWS Organization OUs | list(string) | [] | no |
| role_arn | IAM role ARN for Grafana (if CUSTOMER_MANAGED) | string | "" | no |
| stack_set_name | CloudFormation StackSet name | string | "" | no |
| create_iam_role | Create IAM role for Grafana data source access | bool | true | no |
| create_api_key | Create API key for automation | bool | false | no |
| api_key_ttl | API key time-to-live in seconds | number | 2592000 | no |
| tags | Tags to apply to resources | map(string) | {} | no |

## Outputs

| Name | Description |
|------|-------------|
| workspace_id | Grafana workspace ID |
| workspace_endpoint | Grafana workspace endpoint URL |
| workspace_arn | Grafana workspace ARN |
| iam_role_arn | IAM role ARN for Grafana |
| api_key_secret_arn | Secrets Manager ARN containing Grafana API key (sensitive) |

## Dependencies

### Terraform Providers
- hashicorp/aws >= 5.0

### External Dependencies
- AWS SSO configured (if using AWS_SSO authentication)
- Amazon Managed Prometheus workspace (optional, for Prometheus data source)

### Module Dependencies
None - this module is standalone

## Resources Created

### AWS Resources
- Amazon Managed Grafana workspace
  - Unified alerting enabled
  - Plugin administration enabled
- IAM role (if create_iam_role = true)
  - Trust policy for grafana.amazonaws.com
  - Inline policy for Prometheus and EC2 access
- Grafana API key (if create_api_key = true)
  - ADMIN role
  - Configurable TTL
- Secrets Manager secret (if create_api_key = true)
  - Stores API key, workspace ID, and endpoint

## Authentication Options

### AWS SSO (Recommended)
- Centralized identity management
- MFA support
- No additional configuration needed

### SAML
- Enterprise SSO integration
- Requires SAML IdP configuration
- Supports Okta, Azure AD, etc.

## Data Sources

### Supported Data Sources
- **PROMETHEUS**: Amazon Managed Prometheus (AMP)
- **CLOUDWATCH**: AWS CloudWatch metrics and logs
- **XRAY**: AWS X-Ray traces
- **ATHENA**: Amazon Athena for queries
- **REDSHIFT**: Amazon Redshift data warehouse

## Unified Alerting

Grafana workspace includes unified alerting with:
- Alert rules and recording rules
- SNS notification channels
- Alert state persistence
- Multi-dimensional alerting

## IAM Permissions

When `create_iam_role = true`, the module creates a role with permissions for:
- **AMP**: Query metrics, list workspaces, get labels/series
- **EC2**: Describe instances, tags, regions (for service discovery)

## Cost Considerations

Amazon Managed Grafana pricing:
- Per workspace active user per month
- Free tier: 10 active users per month
- Additional users: charged per user
- No infrastructure costs (fully managed)

## Accessing Grafana

After deployment, access Grafana via:

1. Get workspace endpoint:
   ```bash
   terraform output workspace_endpoint
   ```

2. Sign in via AWS SSO or SAML

3. Configure data sources:
   - Prometheus: Add AMP workspace ARN
   - CloudWatch: Auto-configured
   - X-Ray: Auto-configured

## API Key Usage

If `create_api_key = true`, retrieve the API key from Secrets Manager:

```bash
aws secretsmanager get-secret-value \
  --secret-id <api_key_secret_arn> \
  --query SecretString --output text | jq -r .api_key
```

Use the API key for automation:

```bash
curl -H "Authorization: Bearer $API_KEY" \
  https://<workspace-endpoint>/api/dashboards/home
```

## Dashboard Import

Import pre-built dashboards:

```bash
# Import via Grafana UI: Dashboards → Import
# Or via API
curl -X POST https://<workspace-endpoint>/api/dashboards/db \
  -H "Authorization: Bearer $API_KEY" \
  -H "Content-Type: application/json" \
  -d @dashboard.json
```

## Multi-Account Access

For multi-account monitoring:

1. Set `account_access_type = "ORGANIZATION"`
2. Specify `organizational_units` with OU IDs
3. Set `organization_role_name` to role in member accounts
4. Create IAM role in member accounts with CloudWatch/Prometheus permissions

## Security Considerations

- AWS SSO provides MFA and conditional access
- API keys have configurable TTL (rotate regularly)
- API keys stored in Secrets Manager (encrypted at rest)
- IAM role follows least privilege (scoped to specific actions)
- Workspace access controlled via SSO groups

## Monitoring

Monitor Grafana workspace via CloudWatch metrics:
- `AWS/Grafana` namespace
- Metrics: `ActiveUsers`, `APIRequestCount`, `DataSourceErrors`

## Troubleshooting

### Cannot Access Workspace

Check AWS SSO configuration:
```bash
aws sso-admin list-instances
aws grafana list-workspaces
```

### Data Source Connection Failed

Verify IAM role permissions:
```bash
aws iam get-role-policy \
  --role-name grafana-<env>-role \
  --policy-name <policy-name>
```

### API Key Expired

Rotate API key:
```bash
aws grafana delete-workspace-api-key --key-id <old-key-id> --workspace-id <workspace-id>
terraform apply  # Creates new key
```

## Related Documentation

- [Observability Stack](../../../docs/observability.md)
- [SLO Dashboard Configuration](../../../docs/implementation-summary.md)
- [Amazon Managed Grafana Documentation](https://docs.aws.amazon.com/grafana/)
