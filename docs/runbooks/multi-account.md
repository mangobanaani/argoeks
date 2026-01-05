# Multi-Account Runbook

This runbook keeps AWS Organizations, guardrails, and cross-account Terraform roles in sync with the infrastructure code in `org/`.

## 1. Provision or update the baseline
1. Copy `org/account_map.auto.tfvars.example` to `org/account_map.auto.tfvars` and fill in the real emails + OU keys for each account.
2. Optional: override the default OU tree via `ou_structure_override` if you need additional branches.
3. Run:
   ```bash
   cd org
   terraform init
   terraform plan
   terraform apply
   ```
4. Confirm results:
   ```bash
   aws organizations list-accounts --query 'Accounts[].{Name:Name,Id:Id,Email:Email,Status:Status}'
   aws organizations list-policies --filter SERVICE_CONTROL_POLICY --query 'Policies[].Name'
   ```
5. Share the generated assume-role ARNs (see `module.accounts[0].accounts` output) with the platform team; they populate `workload_account_role_arn` / `management_role_arn` inside each environment’s `terraform.tfvars`.

## 2. Add a new account later
1. Append a new item to `account_definitions` (unique map key) referencing the OU key.
2. `terraform -chdir=org plan -target=module.accounts` to review just the new account.
3. Apply and wait for AWS to finish provisioning (~5 minutes).
4. Verify the invitation email was received and the account shows `ACTIVE`.
5. Rotate `workload_account_role_arn` in downstream environments if you intend to deploy there.

## 3. Rotate cross-account roles
1. Update `iam_role_name` for the account entry or manually edit the role inside the account.
2. Re-run `terraform -chdir=org apply -target=module.accounts`.
3. Update every environment’s `terraform.tfvars` with the new role ARN.
4. Validate by running `aws sts assume-role --role-arn ...` from your workstation.

## 4. Validate guardrails
1. List attached SCPs:
   ```bash
   aws organizations list-policies-for-target \
     --target-id <account-or-ou-id> \
     --filter SERVICE_CONTROL_POLICY \
     --query 'Policies[].Name'
   ```
2. Attempt a disallowed action (e.g., `aws iam create-access-key --user-name test`) using a workload account role to confirm the Deny triggers.
3. For region restrictions, try `aws ec2 describe-vpcs --region eu-central-1` and confirm the request is denied when the region is not in `scp_allowed_regions`.

## 5. CloudTrail / log archive checks
1. Ensure the CloudTrail bucket exists:
   ```bash
   aws s3 ls s3://${local.cloudtrail_bucket_name_resolved}/ --recursive | head
   ```
2. Confirm events are flowing: `aws cloudtrail lookup-events --max-results 5`.
3. If replication is enabled, inspect the destination bucket for mirrored objects.

## 6. Troubleshooting
- **Account stuck in `PENDING`**: run `aws organizations describe-create-account-status --create-account-request-id <id>`; retry via `terraform apply`.
- **SCP denies required action**: update `scp_allowed_session_principals` or `scp_automation_role_arns` in `org/variables.tf`, reapply, and document the exception.
- **CloudTrail access denied**: ensure the IAM principal has `s3:GetObject` for the log bucket and that the bucket policy contains the CloudTrail service statements from the module.

Keep this runbook close to your infra repo. Every cross-account change should be driven through Terraform and recorded (git history + CloudTrail) to maintain compliance.
