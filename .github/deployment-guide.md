# Deployment Guide

## Quick Start

### Manual Deployment Workflow

1. **Create Feature Branch**
```bash
git checkout -b feature/your-feature
# Make changes to terraform/ or kubernetes/ files
git add .
git commit -m "Add new feature"
git push origin feature/your-feature
```

2. **Create Pull Request**
```bash
# GitHub UI or CLI
gh pr create --title "Feature: Add new component" --body "Description"
```

3. **Review Validation**
The pull request will automatically trigger validation:
- Terraform linting and validation
- Kubernetes manifest validation
- Security scanning (tfsec, Checkov)
- Unit tests
- Terraform plan generation

4. **Review and Approve**
- Check the generated Terraform plan in PR comments
- Review security scan results
- Request changes if needed
- Approve when ready

5. **Merge to Main**
```bash
gh pr merge --squash
```

6. **Automatic Production Deployment**
Once merged to main, production deployment requires manual approval:
- GitHub Actions deployment approval
- Production environment protection rules
- CODEOWNERS review (if configured)

### Development Environment Deployment

**For develop branch (Development environment):**
```bash
# Push to develop
git push origin feature-branch:develop

# Workflow triggers automatically
# Check GitHub Actions for progress
gh run list
gh run view <run-id> --log
```

**For main branch (QA environment):**
```bash
# Create PR to main
# After approval and merge
# Manual deployment approval required
```

## Environment Matrix

| Environment | Trigger | Approval | Auto-Deploy | State |
|-------------|---------|----------|-------------|-------|
| sandbox     | PR label | No      | No          | Temporary |
| dev         | develop branch | No | Yes        | Persistent |
| qa          | main branch | Yes    | No          | Persistent |
| prod        | main branch | Yes    | No          | Persistent |

## Sandbox Environment (Pull Requests)

Create temporary infrastructure for testing.

### Enable Sandbox
```bash
# Add 'sandbox' label to PR
gh pr edit <PR_NUMBER> --add-label sandbox

# Workflow will:
# 1. Generate Terraform plan
# 2. Apply infrastructure
# 3. Create temporary EKS cluster
# 4. Deploy preview environment
```

### Access Sandbox
```bash
# Get Terraform outputs
gh run view <run-id> --job sandbox-apply

# Configure kubeconfig
aws eks update-kubeconfig \
  --name sbx-pr-<PR_NUMBER> \
  --region us-east-1
```

### Destroy Sandbox
```bash
# Remove 'sandbox' label or close PR
gh pr edit <PR_NUMBER> --remove-label sandbox

# Or close PR
gh pr close <PR_NUMBER>

# Workflow will automatically destroy infrastructure
```

## Manual Deployments

### Deploy to Dev
```bash
gh workflow run deploy-production.yml \
  -f environment=dev \
  -f terraform-action=apply
```

### Deploy to QA
```bash
gh workflow run deploy-production.yml \
  -f environment=qa \
  -f terraform-action=apply
```

### Deploy to Production
```bash
# Plan only first
gh workflow run deploy-production.yml \
  -f environment=prod \
  -f terraform-action=plan

# Review plan output, then apply
gh workflow run deploy-production.yml \
  -f environment=prod \
  -f terraform-action=apply \
  -f skip-approval=false
```

### Destroy Resources
```bash
gh workflow run deploy-production.yml \
  -f environment=dev \
  -f terraform-action=destroy \
  -f skip-approval=true
```

## GitLab CI Deployments

### Merge Request Sandbox
```bash
# Create MR
git push origin feature-branch

# In GitLab UI:
# 1. Click "Plan" stage for MR pipeline
# 2. Manually trigger "plan:sandbox"
# 3. Review plan output
# 4. Manually trigger "deploy:sandbox"
```

### Development Deployment
```bash
# Push to develop branch
git push origin feature-branch:develop

# In GitLab UI:
# 1. Monitor develop pipeline
# 2. Manually trigger "deploy:dev"
# 3. Check status in Environments
```

### Production Deployment
```bash
# Merge to main branch
git merge develop

# In GitLab UI:
# 1. Go to main pipeline
# 2. Manually trigger "deploy:qa"
# 3. After QA validation
# 4. Manually trigger "deploy:prod"
```

## Rollback Procedures

### Automatic Rollback
Automatic rollback triggers on:
- Smoke test failure
- Health check failure
- Critical security scan failure
- Deployment timeout

To check rollback status:
```bash
gh run view <run-id> --log --job rollback-on-failure
```

### Manual Rollback

**GitHub Actions:**
```bash
# Redeploy previous version
gh workflow run deploy-production.yml \
  -f environment=prod \
  -f terraform-action=apply \
  -f skip-approval=true

# Or use Terraform state
cd terraform/environments/prod
terraform state list
terraform state show <resource>
```

**GitLab CI:**
```bash
# In GitLab UI, rerun a previous pipeline with "apply"
# Or manually run:
cd terraform/environments/prod
terraform init
terraform state pull > state.backup
terraform apply -auto-approve
```

## Drift Reconciliation

### Monitor Drift
```bash
# Check latest drift detection run
gh run list --workflow drift-detection.yml

# View detailed report
gh run view <run-id> --log
```

### Auto-reconcile Non-Prod
```bash
# For dev/qa, drift is automatically reconciled
# Check GitHub issue for details
gh issue list --label drift-detection
```

### Production Drift
```bash
# Review created PR
gh pr list --label drift-reconciliation

# If approved:
git pull origin drift-reconciliation-prod
git merge --ff-only

# Automatic apply via workflow
```

## Cost Monitoring

### View Cost Estimates
```bash
# In Terraform plan output
gh run view <run-id> --job plan-environments

# Or download report
gh run download <run-id> -n infracost-breakdown
```

### Monthly Cost Report
```bash
# Scheduled monthly, or trigger manually
gh workflow run scheduled-compliance.yml \
  -f scan-type=cost
```

## Security Scanning Results

### View Security Scan Results
```bash
# In PR checks
gh pr checks <PR_NUMBER>

# Or view workflow details
gh run view <run-id> --log
```

### Review SARIF Results
```bash
# GitHub Security tab
# Navigate to Security > Code scanning

# Or download artifacts
gh run download <run-id> -n '*-results.sarif'
```

### Container Image Scanning
```bash
# View Trivy results
gh run view <run-id> --job build-and-scan

# Check image vulnerability details
gh run download <run-id> -n trivy-results.sarif
```

## Troubleshooting

### Workflow Failures

**Check logs:**
```bash
# List recent runs
gh run list

# View failed run
gh run view <run-id> --log

# Re-run failed jobs
gh run rerun <run-id> --failed
```

**Common issues:**

1. **Terraform lock timeout**
   - State is locked by another job
   - Solution: Wait or force-unlock in AWS Console

2. **OIDC token expired**
   - Check AWS OIDC provider configuration
   - Verify role trust relationships

3. **Docker image build failure**
   - Check Docker buildx installation
   - Verify image base exists

4. **Kubernetes validation failure**
   - Check YAML syntax
   - Verify Kubernetes API version

### Debugging Tips

**Enable debug logging:**
```bash
# GitHub Actions
gh run view <run-id> --log --verbose
```

**Test locally:**
```bash
# Terraform validation
cd terraform/environments/dev
terraform init -backend=false
terraform validate

# Kubernetes validation
kubeconform -strict kubernetes/**/*.yaml

# Security scan
tfsec terraform/
```

## Performance Optimization

### Speed Up Workflows

1. **Use caching:**
```yaml
- uses: actions/cache@v4
  with:
    path: ~/.terraform.d/plugin-cache
    key: terraform-${{ hashFiles('.terraform.lock.hcl') }}
```

2. **Parallel jobs:**
```yaml
strategy:
  matrix:
    environment: [dev, qa, prod]
  max-parallel: 3
```

3. **Conditional steps:**
```yaml
if: contains(github.event.pull_request.labels.*.name, 'scan-only')
```

### Reduce Deployment Time

1. Skip non-prod scans for hotfixes
2. Cache Docker layers
3. Use smaller base images
4. Limit log verbosity
5. Archive only essential artifacts

## References

- [GitHub Workflows](https://docs.github.com/en/actions/using-workflows)
- [GitLab Pipelines](https://docs.gitlab.com/ee/ci/pipelines/)
- [Terraform CLI](https://www.terraform.io/cli/commands)
- [kubectl Documentation](https://kubernetes.io/docs/reference/kubectl/)
