# CI/CD Pipeline Implementation Checklist

## Pre-Implementation

- [ ] Review all pipeline documentation
- [ ] Assess current infrastructure and tooling
- [ ] Plan rollout strategy (gradual vs. full adoption)
- [ ] Identify stakeholders and communication needs
- [ ] Allocate resources for implementation and maintenance
- [ ] Schedule team training sessions

## GitHub Actions Setup

### Repository Configuration

- [ ] Enable GitHub Actions in repository settings
- [ ] Configure general workflow permissions
  - [ ] Allow local and reusable workflows
  - [ ] Set default permissions to 'read'
  - [ ] Enable 'Pull request' and 'Push' permissions
- [ ] Enable OIDC provider for AWS authentication
  - [ ] Navigate to Settings > Secrets and variables > Actions
  - [ ] Configure trusted entity for GitHub OIDC
  - [ ] Create AWS IAM role with OIDC trust relationship

### Secrets Configuration

- [ ] Create required secrets:
  - [ ] `AWS_IAM_ROLE_ARN` - AWS role for OIDC
  - [ ] `INFRACOST_API_KEY` - Cost estimation (optional)
  - [ ] `SLACK_WEBHOOK_URL` - Notifications (optional)
- [ ] Store in Settings > Secrets and variables > Actions
- [ ] Document secret rotation procedure

### Environment Protection Rules

- [ ] Create 'production' environment
- [ ] Configure protection rules:
  - [ ] Require approval from code owners
  - [ ] Limit deployment branches to 'main'
  - [ ] Set required reviewers
- [ ] Create 'staging' environment (optional)
- [ ] Create 'development' environment (optional)

### Branch Protection

- [ ] Navigate to repository Settings > Branches
- [ ] Configure 'main' branch:
  - [ ] Require pull request reviews (min 1)
  - [ ] Require status checks to pass (PR validation workflow)
  - [ ] Require branches to be up to date
  - [ ] Include administrators
  - [ ] Restrict who can push to matching branches

## AWS OIDC Configuration

### Create OIDC Identity Provider

```bash
# 1. Create OIDC provider
aws iam create-open-id-connect-provider \
  --url https://token.actions.githubusercontent.com \
  --client-id-list sts.amazonaws.com \
  --thumbprint-list [THUMBPRINT]

# 2. Get thumbprint
openssl s_client -showcerts -connect token.actions.githubusercontent.com:443 \
  </dev/null 2>/dev/null | openssl x509 -fingerprint -noout | sed 's/://g'
```

### Create IAM Role

```bash
# 1. Create role with OIDC trust relationship
cat > trust-policy.json << 'EOF'
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "arn:aws:iam::ACCOUNT_ID:oidc-provider/token.actions.githubusercontent.com"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "token.actions.githubusercontent.com:aud": "sts.amazonaws.com"
        },
        "StringLike": {
          "token.actions.githubusercontent.com:sub": "repo:OWNER/REPO:*"
        }
      }
    }
  ]
}
EOF

aws iam create-role \
  --role-name github-actions-argoeks \
  --assume-role-policy-document file://trust-policy.json
```

### Attach Required Policies

- [ ] Create inline policy for Terraform state access:
  ```json
  {
    "Version": "2012-10-17",
    "Statement": [
      {
        "Effect": "Allow",
        "Action": [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject",
          "dynamodb:GetItem",
          "dynamodb:PutItem"
        ],
        "Resource": [
          "arn:aws:s3:::terraform-state-bucket/*",
          "arn:aws:dynamodb:*:*:table/terraform-locks"
        ]
      }
    ]
  }
  ```

- [ ] Attach AWS managed policies:
  - [ ] `AdministratorAccess` (for testing, restrict to specific services in prod)
  - Or specific service policies for production

## GitLab CI Setup

### Project Configuration

- [ ] Navigate to Project Settings > CI/CD
- [ ] Configure CI/CD variables:
  - [ ] `AWS_ROLE_ARN` - AWS role for OIDC
  - [ ] `KUBECONFIG_CONTENT` - Base64-encoded kubeconfig
  - [ ] `ARGOCD_SERVER_URL` - ArgoCD server URL
  - [ ] `ARGOCD_AUTH_TOKEN` - ArgoCD authentication token
  - [ ] `HARBOR_REGISTRY` - Harbor registry URL (optional)
  - [ ] `HARBOR_USERNAME` - Harbor credentials (optional)
  - [ ] `HARBOR_PASSWORD` - Harbor credentials (optional)

### Enable Features

- [ ] Settings > CI/CD > Visibility:
  - [ ] Make CI/CD pipelines public (or configure access)
- [ ] Settings > CI/CD > Pipeline:
  - [ ] Enable pipeline success/failure notifications
  - [ ] Configure timeout (default: 60 minutes)
- [ ] Settings > CI/CD > Variables:
  - [ ] Mark sensitive variables as protected/masked

### Create `.gitlab/ci` Directory Structure

```bash
mkdir -p .gitlab/ci
touch .gitlab/ci/{terraform,security,containers,kubernetes}.yml
```

### Environment Configuration

- [ ] Create deployment environments:
  - [ ] 'development' (dev)
  - [ ] 'staging' (qa)
  - [ ] 'production' (prod)
- [ ] Configure protection for each environment:
  - [ ] Production requires approval
  - [ ] Limit deployment branches

## Terraform Backend Setup

### S3 Bucket Creation

```bash
# Create bucket for Terraform state
aws s3api create-bucket \
  --bucket terraform-state-argoeks-ACCOUNT_ID \
  --region us-east-1

# Enable versioning
aws s3api put-bucket-versioning \
  --bucket terraform-state-argoeks-ACCOUNT_ID \
  --versioning-configuration Status=Enabled

# Enable encryption
aws s3api put-bucket-encryption \
  --bucket terraform-state-argoeks-ACCOUNT_ID \
  --server-side-encryption-configuration '{
    "Rules": [{
      "ApplyServerSideEncryptionByDefault": {
        "SSEAlgorithm": "AES256"
      }
    }]
  }'

# Block public access
aws s3api put-public-access-block \
  --bucket terraform-state-argoeks-ACCOUNT_ID \
  --public-access-block-configuration \
  "BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true"
```

### DynamoDB Table for Locking

```bash
aws dynamodb create-table \
  --table-name terraform-locks \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST
```

### Backend Configuration

- [ ] Update `terraform/backends.tf`:
  ```hcl
  terraform {
    backend "s3" {
      bucket         = "terraform-state-argoeks-ACCOUNT_ID"
      key            = "terraform.tfstate"
      region         = "us-east-1"
      encrypt        = true
      dynamodb_table = "terraform-locks"
    }
  }
  ```

## Docker/Container Registry Setup

### GitHub Container Registry (GHCR)

- [ ] Enable GHCR in repository settings
- [ ] Create personal access token (PAT):
  - [ ] Navigate to Settings > Developer settings > Personal access tokens
  - [ ] Grant 'write:packages' scope
  - [ ] Store token securely
- [ ] Create `REGISTRY_TOKEN` secret in GitHub

### AWS ECR (optional)

```bash
# Create ECR repository
aws ecr create-repository \
  --repository-name argoeks \
  --region us-east-1 \
  --encryption-configuration encryptionType=AES
```

## Documentation and Testing

### Create Required Documentation

- [ ]  CI/CD Pipelines documentation (`docs/CI_CD_PIPELINES.md`)
- [ ]  Deployment Guide (`.github/DEPLOYMENT_GUIDE.md`)
- [ ]  Pipeline Architecture (`.github/PIPELINE_ARCHITECTURE.md`)
- [ ]  Runbook for common tasks
- [ ]  Troubleshooting guide

### Test Pipeline Workflows

- [ ] Test pull request validation workflow:
  - [ ] Create feature branch
  - [ ] Make test changes
  - [ ] Create PR
  - [ ] Verify validation workflow runs
  - [ ] Check workflow outputs

- [ ] Test sandbox deployment:
  - [ ] Add 'sandbox' label to test PR
  - [ ] Verify sandbox workflow triggers
  - [ ] Check temporary resources created
  - [ ] Verify cleanup on label removal

- [ ] Test production deployment (staging):
  - [ ] Merge to main (or test branch)
  - [ ] Verify deployment workflow runs
  - [ ] Approve deployment
  - [ ] Verify resources deployed

### Validate Security

- [ ] [ ] Test OIDC authentication:
  ```bash
  gh run view <run-id> --log | grep "Configure AWS"
  ```

- [ ] [ ] Test secret masking in logs
- [ ] [ ] Verify no secrets exposed in artifacts
- [ ] [ ] Test branch protection enforcement

## Training and Documentation

### Team Training

- [ ] Conduct pipeline overview session
- [ ] Demo GitHub Actions workflows
- [ ] Demo GitLab CI pipelines
- [ ] Train on deployment process
- [ ] Practice rollback procedures
- [ ] Document team-specific configurations

### Create Runbooks

- [ ] How to deploy to each environment
- [ ] How to rollback failed deployments
- [ ] How to handle drift detection
- [ ] How to monitor pipeline health
- [ ] How to add new applications
- [ ] How to manage secrets

## Monitoring and Alerting

### Setup Notifications

- [ ] Configure Slack integration:
  - [ ] Create Slack workspace
  - [ ] Create incoming webhook
  - [ ] Store URL in secrets
  - [ ] Test notifications

- [ ] Configure email notifications:
  - [ ] Set GitHub Actions email preferences
  - [ ] Set GitLab pipeline notifications

### Create Dashboards

- [ ] GitHub Actions dashboard:
  - [ ] Workflow success rate
  - [ ] Average build time
  - [ ] Failed workflow trends

- [ ] GitLab CI dashboard:
  - [ ] Pipeline duration
  - [ ] Stage success rates
  - [ ] Job failure analysis

## Post-Implementation

### Validation

- [ ] Run validation script:
  ```bash
  bash scripts/validate-pipelines.sh
  ```

- [ ] Verify all workflows are discoverable:
  - [ ] GitHub: Actions tab shows all workflows
  - [ ] GitLab: CI/CD > Pipelines shows all jobs

- [ ] Test disaster recovery:
  - [ ] Simulate workflow failure
  - [ ] Verify rollback executes
  - [ ] Verify notifications sent

### Documentation

- [ ] Update team wiki/knowledge base
- [ ] Document team-specific processes
- [ ] Create troubleshooting guide
- [ ] Document approval processes
- [ ] Create cost tracking documentation

### Handoff

- [ ] Train ops team on pipeline management
- [ ] Provide on-call runbooks
- [ ] Schedule regular review meetings
- [ ] Plan quarterly optimization reviews
- [ ] Document known issues and workarounds

## Ongoing Maintenance

### Weekly

- [ ] Review failed pipelines
- [ ] Check deployment success rates
- [ ] Monitor cost trends
- [ ] Review security scan results

### Monthly

- [ ] Update tool versions
- [ ] Review and update policies
- [ ] Analyze pipeline metrics
- [ ] Plan improvements

### Quarterly

- [ ] Full pipeline review
- [ ] Security audit
- [ ] Performance optimization
- [ ] Cost analysis and optimization
- [ ] Team feedback collection

## Troubleshooting Quick Reference

| Issue | Solution |
|-------|----------|
| OIDC token error | Verify OIDC provider trust relationship |
| State lock timeout | Force unlock in DynamoDB or S3 |
| Workflow not running | Check branch protection rules and push permissions |
| Secret not available | Verify secret exists and is not masked incorrectly |
| Build timeout | Increase timeout in workflow or optimize build |
| Deployment failed | Check logs, rollback, investigate root cause |
| Drift detected | Review issue, approve PR, merge to deploy fix |

## Success Criteria

- [ ] All workflows execute successfully
- [ ] Deployments complete in < 15 minutes (non-prod)
- [ ] Deployments complete in < 30 minutes (prod with approval)
- [ ] Security scans run and report findings
- [ ] Cost estimation available for all environments
- [ ] Notifications sent for important events
- [ ] Team trained and confident in pipeline usage
- [ ] Documentation complete and accessible
- [ ] Rollback procedures tested and working
- [ ] Monitoring and alerting in place
