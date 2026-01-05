# account_factory

Creates AWS member accounts under specific Organizational Units and outputs the assume-role ARNs Terraform should use. Each entry declares the target OU key, email, optional display name, and desired IAM role name (defaults to `OrganizationAccountAccessTerraform`).

## Usage

```hcl
module "org_ous" {
  source       = "../modules/ou"
  ou_structure = local.default_ou_structure
}

module "accounts" {
  source              = "../modules/account_factory"
  account_definitions = {
    shared_services = {
      email  = "aws+shared@example.com"
      ou_key = "shared-services"
    }
    training = {
      email         = "aws+training@example.com"
      ou_key        = "training"
      iam_role_name = "OrganizationAccountAccessTerraform"
    }
  }
  ou_id_map = module.org_ous.ou_ids
}
```

## Inputs

- `account_definitions` – map of logical names => `{ email, ou_key, name?, iam_role_name?, tags? }`
- `ou_id_map` – OU IDs from the OU module (map of key => OU id)

## Outputs

- `accounts` – map of logical name => `{ id, arn, email, role_name, assume_role_arn, ou_id }`
