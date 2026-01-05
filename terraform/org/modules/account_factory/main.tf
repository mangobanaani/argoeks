terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
    }
  }
}

# Creates AWS accounts under the specified OUs and exposes role ARNs for cross-account access.
resource "aws_organizations_account" "member" {
  for_each = var.account_definitions

  name                     = coalesce(each.value.name, title(replace(each.key, "-", " ")))
  email                    = each.value.email
  parent_id                = var.ou_id_map[each.value.ou_key]
  role_name                = each.value.iam_role_name
  close_on_deletion        = true
  iam_user_access_to_billing = "ALLOW"

  tags = each.value.tags
}
