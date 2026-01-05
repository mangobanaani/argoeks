provider "aws" {
  region  = var.region
  profile = var.aws_profile

  dynamic "assume_role" {
    for_each = var.workload_account_role_arn != "" ? [var.workload_account_role_arn] : []
    content {
      role_arn     = assume_role.value
      session_name = "terraform-${var.name_prefix}"
      external_id  = var.assume_role_external_id != "" ? var.assume_role_external_id : null
    }
  }
}

provider "aws" {
  alias  = "billing"
  region = "us-east-1"

  dynamic "assume_role" {
    for_each = var.management_role_arn != "" ? [var.management_role_arn] : []
    content {
      role_arn     = assume_role.value
      session_name = "terraform-billing-${var.name_prefix}"
    }
  }
}
