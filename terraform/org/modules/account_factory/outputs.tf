locals {
  account_summaries = {
    for key, acct in aws_organizations_account.member :
    key => {
      id              = acct.id
      arn             = acct.arn
      email           = acct.email
      role_name       = acct.role_name
      assume_role_arn = "arn:aws:iam::${acct.id}:role/${acct.role_name}"
      ou_id           = acct.parent_id
    }
  }
}

output "accounts" {
  description = "Details for each provisioned account (id, assume role ARN, etc.)."
  value       = local.account_summaries
}
