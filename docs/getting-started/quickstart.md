# Quick Start - Terraform Testing

## Setup (First Time)

### 1. Load AWS Credentials

```bash
# Load credentials from .env file
source .env

# Verify credentials are loaded
aws sts get-caller-identity
# Should show: arn:aws:iam::555989351930:user/psl
```

### 2. Test Terraform Plan

```bash
# Using Makefile (recommended)
make plan ENV=dev

# Or directly
cd terraform/environments/dev
terraform init
terraform plan
```

## Common Commands

### Using Makefile (Recommended)

```bash
# Show all available commands
make help

# Plan specific environment
make plan ENV=dev
make plan ENV=qa
make plan ENV=prod
make plan ENV=sandbox

# Shortcuts (same as plan)
make dev      # Plans dev environment
make qa       # Plans qa environment
make prod     # Plans prod environment
make sandbox  # Plans sandbox environment

# Apply changes (auto-approve)
make apply ENV=dev

# Show outputs
make output ENV=dev

# Validate configuration
make validate ENV=dev

# Format code
make fmt

# Clean cache
make clean ENV=dev
```

### Direct Terraform Commands

```bash
# Initialize
cd terraform/environments/dev
terraform init

# Plan
terraform plan

# Apply
terraform apply

# Show outputs
terraform output

# Destroy (careful!)
terraform destroy
```

## Environments

| Environment | Path | Purpose |
|-------------|------|---------|
| **dev** | `terraform/environments/dev` | Development, ML workload testing |
| **qa** | `terraform/environments/qa` | QA testing, validation |
| **prod** | `terraform/environments/prod` | Production (multi-region) |
| **sandbox** | `terraform/environments/sandbox` | Experimentation |

## Workflow Example

```bash
# 1. Load credentials
source .env

# 2. Plan dev environment
make plan ENV=dev

# 3. Review the plan output
#    - Check resources to be created
#    - Verify configurations
#    - Check for any errors

# 4. Apply if plan looks good
make apply ENV=dev

# 5. View outputs
make output ENV=dev
```

## Troubleshooting

### AWS Credentials Not Found

```bash
# Error: AWS credentials not set
# Fix: Source the .env file
source .env

# Verify
echo $AWS_ACCESS_KEY_ID
# Should show: AKIAYC44MHX5ENEOS66T
```

### Environment Not Found

```bash
# Error: Environment 'xyz' not found
# Fix: Use valid environment name
make plan ENV=dev    #  Valid
make plan ENV=xyz    #  Invalid
```

### Terraform Lock File Issues

```bash
# Clean and reinitialize
make clean ENV=dev
make init ENV=dev
```

## Security Reminders

 **IMPORTANT**:
- The `.env` file contains **real AWS credentials**
- This is for **testing only**
- **Never commit** `.env` to git (it's in `.gitignore`)
- **Scrub credentials** when done testing

To check if `.env` is protected:
```bash
git status --ignored
# .env should appear in ignored files
```

## Optional Modules

Want to enable optional features like VPC Lattice, ECR scanning, etc.?

```bash
# Copy the example file
cp terraform/environments/dev/optional-modules.tf.example \
   terraform/environments/dev/optional-modules.tf

# Edit and uncomment the modules you want
vim terraform/environments/dev/optional-modules.tf

# Plan to see what will be added
make plan ENV=dev
```

See `docs/OPTIONAL_MODULES_GUIDE.md` for details on each optional module.

## Next Steps

After testing:

1. **Review the plan output** carefully
2. **Verify IAM permissions** for your user
3. **Check costs** - use `terraform plan` to estimate
4. **Apply incrementally** - start with dev, then qa, then prod
5. **Monitor CloudTrail** for any unexpected API calls
6. **Scrub test credentials** when done

## Resources

- **Stack optimization**: `docs/STACK_OPTIMIZATION_2026-01.md`
- **Optional modules**: `docs/OPTIONAL_MODULES_GUIDE.md`
- **Cilium setup**: `docs/CILIUM_ENABLEMENT.md`
- **Terraform structure**: `docs/TERRAFORM_IMPROVEMENTS_2026-01.md`
