# Terraform Module and Provider Versions

**Last Updated:** January 3, 2026

This document tracks all Terraform providers and modules used in the project, ensuring we're using the latest stable versions.

## Provider Versions

### Core Providers (Dev Environment)

| Provider | Version | Latest Available | Status | Notes |
|----------|---------|------------------|---------|-------|
| **AWS** | 6.27.0 | 6.27.0 | Latest | Released Dec 18, 2025 |
| **Kubernetes** | 3.0.1 | 3.0.1 | Latest | Released Dec 9, 2024 |
| **Helm** | 3.1.1 | 3.1.1 | Latest | Released mid-Dec 2025 |
| **Random** | 3.7.2 | 3.7.2 | Latest | - |
| **Null** | >= 3.2.4 | 3.2.4 | Latest | - |

**File:** `terraform/environments/dev/providers.tf`

### Minimum Required Versions (Cluster Factory Module)

| Provider | Minimum Version | Notes |
|----------|----------------|-------|
| **AWS** | >= 6.27.0 | Updated to match latest |
| **Null** | >= 3.2.4 | Updated to match latest |

**File:** `terraform/modules/cluster_factory/versions.tf`

## Module Versions

### AWS Modules

| Module | Version | Latest Available | Status | Notes |
|--------|---------|------------------|--------|-------|
| **terraform-aws-modules/vpc/aws** | 6.5.1 | 6.5.1 | Latest | Fixes deprecated attributes |
| **terraform-aws-modules/eks/aws** | 21.10.1 | 21.10.1 | Latest | Released Nov 27, 2024 |

**File:** `terraform/modules/cluster_factory/main.tf`

## Version Upgrade Notes

### AWS Provider 6.27.0

**Key Features:**
- Tag policy compliance enforcement via `tag_policy_compliance` provider argument
- Requires `tags:ListRequiredTags` IAM permission when enabled
- Support for Amazon S3's March 2026 default security settings
- New `blocked_encryption_types` argument for S3 buckets

**References:**
- [GitHub Releases](https://github.com/hashicorp/terraform-provider-aws/releases)
- [Terraform Registry](https://registry.terraform.io/providers/hashicorp/aws/latest)

### Kubernetes Provider 3.0.1

**Breaking Changes from 2.x:**
- Migrated from Terraform Plugin SDK v2 to Plugin Framework
- Uses Terraform Plugin Protocol Version 6
- Blocks like `kubernetes`, `registry`, `experiments` are now nested objects
- Requires Terraform >= 1.0

**Upgrade Path:**
- Review the [v3 Upgrade Guide](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/guides/v3-upgrade-guide)
- Test in non-production environment first
- Users on Terraform < 1.0 should pin to `~> 2.38`

**References:**
- [GitHub Releases](https://github.com/hashicorp/terraform-provider-kubernetes/releases)
- [Terraform Registry](https://registry.terraform.io/providers/hashicorp/kubernetes/latest)

### Helm Provider 3.1.1

**Breaking Changes from 2.x:**
- Migrated to Terraform Plugin Framework
- `set`, `set_list`, `set_sensitive` in `helm_release` are now lists of nested objects
- Requires Terraform >= 1.0

**Upgrade Path:**
- Review the [v3 Upgrade Guide](https://registry.terraform.io/providers/hashicorp/helm/latest/docs/guides/v3-upgrade-guide)
- Update HCL syntax for set blocks
- Test Helm releases in dev environment

**References:**
- [GitHub Releases](https://github.com/hashicorp/terraform-provider-helm/releases)
- [Terraform Registry](https://registry.terraform.io/providers/hashicorp/helm/latest)

### EKS Module 21.10.1

**Key Features (v21.x series):**
- Native EKS Pod Identity support (IRSA support removed)
- AWS Provider v6 compatibility
- Kubernetes 1.33 support
- EKS Auto Mode support
- Provisioned Control Plane support
- Node repair configuration

**Breaking Changes from 20.x:**
- EKS Pod Identity enabled by default
- IRSA (IAM Roles for Service Accounts) native support removed
- Must use separate IRSA module if needed

**Upgrade Path:**
- Review [UPGRADE-21.0.md](https://github.com/terraform-aws-modules/terraform-aws-eks/blob/master/docs/UPGRADE-21.0.md)
- Plan Pod Identity migration strategy
- Test in dev environment with both managed and self-managed node groups

**References:**
- [GitHub Releases](https://github.com/terraform-aws-modules/terraform-aws-eks/releases)
- [Terraform Registry](https://registry.terraform.io/modules/terraform-aws-modules/eks/aws/latest)

### VPC Module 6.5.1

**Changes from 5.x:**
- Fixes deprecated `log_group.name` attribute warnings
- Improved VPC flow logs configuration
- Better IPv6 support
- Enhanced tagging capabilities

**References:**
- [GitHub Releases](https://github.com/terraform-aws-modules/terraform-aws-vpc/releases)
- [Terraform Registry](https://registry.terraform.io/modules/terraform-aws-modules/vpc/aws/latest)

## Version Update Checklist

When updating provider or module versions:

- [ ] Check release notes for breaking changes
- [ ] Review upgrade guides (if major version)
- [ ] Update `terraform/environments/dev/providers.tf`
- [ ] Update `terraform/modules/cluster_factory/versions.tf`
- [ ] Run `terraform init -upgrade`
- [ ] Run `terraform plan` and review changes
- [ ] Test in dev environment first
- [ ] Document any configuration changes needed
- [ ] Update this document with new versions

## Terraform Version

**Minimum Required:** >= 1.5.0

**Recommended:** Use the latest stable Terraform CLI version

```bash
# Check current version
terraform version

# Upgrade Terraform (via tfenv)
tfenv install latest
tfenv use latest
```

## Checking for Updates

### Automated Checks

```bash
# Check for provider updates
terraform init -upgrade

# View provider versions
terraform version

# Check module versions
terraform providers
```

### Manual Checks

- **Providers:** https://registry.terraform.io/browse/providers
- **AWS Provider:** https://github.com/hashicorp/terraform-provider-aws/releases
- **EKS Module:** https://github.com/terraform-aws-modules/terraform-aws-eks/releases
- **VPC Module:** https://github.com/terraform-aws-modules/terraform-aws-vpc/releases

## Version Lock Files

### Development Environment

**File:** `terraform/environments/dev/.terraform.lock.hcl`

This file locks provider versions for reproducible builds. To update:

```bash
cd terraform/environments/dev

# Upgrade providers and update lock file
terraform init -upgrade

# Commit the updated lock file
git add .terraform.lock.hcl
git commit -m "Update Terraform provider lock file"
```

## Compatibility Matrix

| Terraform | AWS Provider | Kubernetes Provider | Helm Provider | EKS Module | VPC Module |
|-----------|-------------|---------------------|---------------|------------|------------|
| >= 1.5.0 | 6.27.0 | 3.0.1 | 3.1.1 | 21.10.1 | 6.5.1 |
| >= 1.0.0 | 6.x | 3.x | 3.x | 21.x | 6.x |
| < 1.0.0 | Not supported | Not supported | Not supported | Not supported | Not supported |

## References

- [Terraform AWS Provider Version 6 Upgrade Guide](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/guides/version-6-upgrade)
- [Kubernetes Provider Version 3 Upgrade Guide](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/guides/v3-upgrade-guide)
- [Helm Provider Version 3 Upgrade Guide](https://registry.terraform.io/providers/hashicorp/helm/latest/docs/guides/v3-upgrade-guide)
- [EKS Module Version 21 Upgrade Guide](https://github.com/terraform-aws-modules/terraform-aws-eks/blob/master/docs/UPGRADE-21.0.md)
- [Terraform Version Constraints](https://developer.hashicorp.com/terraform/language/expressions/version-constraints)
