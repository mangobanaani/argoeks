# Tagging Module

This module provides standardized tagging for all AWS resources to enable:
- Cost allocation and tracking
- Resource organization
- Compliance requirements
- Operational management

## Tag Categories

### Cost Allocation Tags
- **CostCenter**: Billing department or team
- **Project**: Project name for cost tracking
- **Environment**: Environment identifier (dev, qa, prod)
- **Owner**: Team or individual responsible
- **Application**: Application name

### Technical Tags
- **TerraformWorkspace**: Terraform workspace
- **TerraformModule**: Module that created the resource
- **GitRepo**: Source repository
- **ManagedBy**: Management tool (Terraform)

### Compliance Tags
- **Compliance**: Compliance frameworks (PCI-DSS, HIPAA, SOC2)
- **DataClass**: Data classification level
- **BackupPolicy**: Backup retention policy

## Usage

```hcl
module "tags" {
  source = "../../modules/common/tags"

  project     = "mlops-platform"
  environment = "prod"
  module_name = "cluster_factory"

  compliance_requirements = "SOC2,PCI-DSS"
  data_classification     = "confidential"
  backup_policy           = "multi-region-replicated"

  additional_tags = {
    Team    = "platform-engineering"
    Service = "eks"
  }
}

resource "aws_eks_cluster" "example" {
  name = "my-cluster"
  tags = module.tags.tags
}
```

## AWS Cost Allocation Tags

These tags are automatically activated in AWS Billing:
- CostCenter
- Environment
- Project
- Application
- Owner

Enable cost allocation tags in AWS Console:
AWS Billing → Cost Allocation Tags → Activate tags
