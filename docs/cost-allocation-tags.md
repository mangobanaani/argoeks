# Cost Allocation Tags

## Overview

This project uses standardized cost allocation tags to enable detailed billing analysis and cost attribution across AWS resources.

## Standard Tags Applied to All Resources

### Cost Allocation Tags
- **CostCenter**: Billing department (e.g., `engineering`, `production`)
- **Project**: Project identifier for cost tracking (e.g., `dev-mlops`, `prod-mlops`)
- **Environment**: Environment name (`dev`, `qa`, `prod`)
- **Owner**: Team or individual responsible (e.g., `platform-team`)
- **Application**: Application name (`argoeks`)

### Technical Tags
- **ManagedBy**: Infrastructure management tool (`Terraform`)
- **TerraformWorkspace**: Terraform workspace used
- **TerraformModule**: Module that created the resource

### Compliance Tags
- **Compliance**: Compliance frameworks (`PCI-DSS`, `HIPAA`, `SOC2`)
- **DataClassification**: Data sensitivity level (`public`, `internal`, `confidential`, `restricted`)
- **BackupPolicy**: Backup retention policy (`daily`, `weekly`, `multi-region-replicated`)

## Activating Cost Allocation Tags in AWS

### Step 1: Enable User-Defined Cost Allocation Tags

1. Sign in to AWS Management Console
2. Navigate to **AWS Billing and Cost Management**
3. In the navigation pane, choose **Cost Allocation Tags**
4. Select the **User-defined cost allocation tags** tab
5. Activate the following tags:
   - `CostCenter`
   - `Project`
   - `Environment`
   - `Owner`
   - `Application`
   - `Compliance`
   - `DataClassification`
   - `BackupPolicy`

6. Click **Activate**

**Note**: It can take up to 24 hours for tags to appear in Cost Explorer after activation.

### Step 2: Verify Tags in Cost Explorer

1. Navigate to **AWS Cost Explorer**
2. Choose **Create report**
3. Group by: Select one of the activated tags (e.g., `Environment`)
4. Verify that costs are properly attributed

## Cost Reports by Tag

### By Environment
```bash
# View costs grouped by environment
aws ce get-cost-and-usage \
  --time-period Start=YYYY-MM-01,End=YYYY-MM-31 \
  --granularity MONTHLY \
  --metrics UnblendedCost \
  --group-by Type=TAG,Key=Environment
```

### By Project
```bash
# View costs grouped by project
aws ce get-cost-and-usage \
  --time-period Start=YYYY-MM-01,End=YYYY-MM-31 \
  --granularity MONTHLY \
  --metrics UnblendedCost \
  --group-by Type=TAG,Key=Project
```

### By Cost Center
```bash
# View costs grouped by cost center
aws ce get-cost-and-usage \
  --time-period Start=YYYY-MM-01,End=YYYY-MM-31 \
  --granularity MONTHLY \
  --metrics UnblendedCost \
  --group-by Type=TAG,Key=CostCenter
```

## Creating Cost Allocation Reports

### Monthly Cost Summary
1. Go to **AWS Cost Explorer**
2. Create a new report:
   - **Name**: Monthly Cost by Environment
   - **Time range**: Last 3 months
   - **Granularity**: Monthly
   - **Group by**: Tag: Environment
   - **Filters**: None or specific services

3. Save and schedule the report for monthly delivery

### Budget Alerts by Environment
1. Go to **AWS Budgets**
2. Create budget:
   - **Budget type**: Cost budget
   - **Name**: `dev-environment-budget`
   - **Period**: Monthly
   - **Budgeted amount**: $500 (adjust as needed)
   - **Filters**: Add filter for Tag: Environment = dev

3. Configure alerts at 80%, 100%, and 120% thresholds

## Tag Configuration by Environment

### Development (dev)
```yaml
CostCenter: engineering
Project: dev-mlops
Environment: dev
DataClassification: internal
BackupPolicy: daily
Compliance: none
```

### Production (prod)
```yaml
CostCenter: production
Project: prod-mlops
Environment: prod
DataClassification: confidential
BackupPolicy: multi-region-replicated
Compliance: SOC2,PCI-DSS
```

## Resource-Specific Tags

### EKS Clusters
Additional tags automatically applied:
- `kubernetes.io/cluster/<cluster-name>`: `owned`
- `karpenter.sh/discovery`: `<cluster-name>`

### Karpenter Nodes
Additional tags automatically applied:
- `karpenter.sh/discovery`: `<cluster-name>`
- `karpenter.sh/nodepool`: `<nodepool-name>`

### Backup Resources (Velero)
Additional tags automatically applied:
- `velero.io/backup`: `<backup-name>`
- `velero.io/schedule`: `<schedule-name>`

## Cost Optimization Recommendations

1. **Review monthly**: Set up monthly cost reviews grouped by Environment and Project
2. **Set budgets**: Create budgets for each environment with alerts
3. **Clean up unused resources**: Use tags to identify and remove unused resources
4. **Right-sizing**: Use CostCenter tag to track team-specific spend and optimize
5. **Reserved Instances**: Use Project tag to identify stable workloads for RI purchases

## Tagging Compliance

All Terraform modules in this project automatically apply standard tags. To add custom tags:

```hcl
module "cluster_factory" {
  source = "../../modules/cluster_factory"

  # Standard tagging parameters
  cost_center             = "engineering"
  project                 = "dev-mlops"
  environment             = "dev"
  compliance_requirements = "SOC2"
  data_classification     = "confidential"

  # Additional custom tags
  additional_tags = {
    Team    = "platform-engineering"
    Contact = "platform@example.com"
  }
}
```

## References

- [AWS Cost Allocation Tags](https://docs.aws.amazon.com/awsaccountbilling/latest/aboutv2/cost-alloc-tags.html)
- [AWS Cost Explorer](https://docs.aws.amazon.com/cost-management/latest/userguide/ce-what-is.html)
- [AWS Budgets](https://docs.aws.amazon.com/cost-management/latest/userguide/budgets-managing-costs.html)
