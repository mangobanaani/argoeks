# Terraform Environments

This directory contains environment-specific Terraform configurations.

## Structure

```
environments/
├── dev/          # Development environment
├── qa/           # QA/Staging environment
├── prod/         # Production environment (multi-region HA)
├── sandbox/      # Experimental/testing environment
└── README.md     # This file
```

## Environment Overview

### Development (`dev/`)
**Purpose**: Daily development and testing

- **Clusters**: 1 hub cluster
- **Size**: Small, cost-optimized
- **Features**: Core services only
- **Databases**: Optional (disabled by default)
- **Logging**: 7-day retention
- **Cost**: ~$200-500/month

**Use for**:
- Feature development
- Integration testing
- Experimentation
- Training

### QA (`qa/`)
**Purpose**: Pre-production validation

- **Clusters**: 1-3 clusters
- **Size**: Medium, production-like
- **Features**: Full feature set
- **Databases**: Enabled
- **Logging**: 30-day retention
- **Cost**: ~$500-1000/month

**Use for**:
- Release candidate testing
- Performance testing
- User acceptance testing
- Security validation

### Production (`prod/`)
**Purpose**: Live production workloads

- **Clusters**: Multi-region HA setup
- **Size**: Large, auto-scaling
- **Features**: Full stack + DR
- **Databases**: Aurora Global, multi-AZ
- **Logging**: 400-day retention
- **Cost**: ~$2000-5000/month

**Use for**:
- Production ML inference
- Customer-facing services
- Critical workloads
- 24/7 operations

### Sandbox (`sandbox/`)
**Purpose**: Experimentation and POCs

- **Clusters**: 1 ephemeral cluster
- **Size**: Variable
- **Features**: Anything goes
- **Databases**: Optional
- **Logging**: Minimal
- **Cost**: Variable, can be destroyed

**Use for**:
- Proof of concepts
- New technology evaluation
- Training sessions
- Temporary demos

## File Structure (Per Environment)

Each environment follows the same clean structure:

```
{env}/
├── main.tf           # Complete infrastructure definition
├── variables.tf      # Input variables
├── outputs.tf        # Output values
├── terraform.tfvars  # Environment-specific values
└── README.md         # Environment documentation
```

## Usage Pattern

### 1. Initialize Environment

```bash
cd terraform/environments/dev
terraform init
```

### 2. Review Changes

```bash
terraform plan
```

### 3. Apply Changes

```bash
terraform apply
```

### 4. Access Outputs

```bash
terraform output
```

## Promotion Path

Typical promotion flow:

```
sandbox → dev → qa → prod
   ↑       ↑     ↑      ↑
  POC    Dev   Test   Live
```

1. **Sandbox**: Experiment with new features
2. **Dev**: Develop and integrate
3. **QA**: Validate and test
4. **Prod**: Deploy to production

## Configuration Management

### Shared Configuration

Common platform settings in `/config/platform.yaml`:
- Service versions
- Default resource sizes
- Network CIDR ranges
- Common tags

### Environment-Specific

Each environment's `terraform.tfvars`:
- Cluster count
- Instance sizes
- Feature flags
- Region settings
- Retention policies

## Security Considerations

- **Credentials**: Use `.env` files (gitignored) or AWS profiles
- **State**: Remote state recommended (S3 + DynamoDB)
- **Secrets**: Never commit secrets to version control
- **RBAC**: Use separate IAM roles per environment
- **Network**: Isolated VPCs per environment

## Best Practices

1. **Always plan before apply**: Review changes carefully
2. **Use workspaces sparingly**: Prefer separate directories
3. **Tag all resources**: Include environment tags
4. **Document changes**: Update README when adding features
5. **Test in lower envs first**: dev → qa → prod
6. **Maintain parity**: Keep configs similar across environments
7. **Clean up**: Destroy sandbox/dev when not in use

## Troubleshooting

### State Lock Issues
```bash
# Force unlock if needed (use carefully!)
terraform force-unlock <lock-id>
```

### Provider Version Conflicts
```bash
# Upgrade providers
terraform init -upgrade
```

### Clean State
```bash
# Remove .terraform and reinit
rm -rf .terraform .terraform.lock.hcl
terraform init
```

## Additional Resources

- [Terraform Docs](https://www.terraform.io/docs)
- [AWS Provider Docs](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
- [EKS Best Practices](https://aws.github.io/aws-eks-best-practices/)
- [Cilium Docs](https://docs.cilium.io/)
