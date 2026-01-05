locals {
  # Standard cost allocation tags
  cost_allocation_tags = {
    CostCenter  = var.cost_center
    Project     = var.project
    Environment = var.environment
    ManagedBy   = "Terraform"
    Owner       = var.owner
    Application = var.application
  }

  # Technical tags
  technical_tags = {
    TerraformWorkspace = terraform.workspace
    TerraformModule    = var.module_name
    GitRepo            = var.git_repo
  }

  # Compliance tags
  compliance_tags = {
    Compliance   = var.compliance_requirements
    DataClass    = var.data_classification
    BackupPolicy = var.backup_policy
  }

  # Merged tags
  all_tags = merge(
    local.cost_allocation_tags,
    local.technical_tags,
    local.compliance_tags,
    var.additional_tags
  )
}
