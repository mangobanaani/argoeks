# NOTE: This module assumes you run in the management (payer) account with Organizations enabled.
data "aws_organizations_organization" "org" {}

locals {
  root_id = data.aws_organizations_organization.org.roots[0].id
}

resource "aws_organizations_organizational_unit" "ou" {
  for_each = var.ou_structure

  name = each.key
  parent_id = each.value == "root"
    ? local.root_id
    : aws_organizations_organizational_unit.ou[each.value].id
}
