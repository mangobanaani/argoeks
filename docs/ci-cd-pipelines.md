# CI/CD Pipeline Documentation

## Overview

The ArgoEKS platform implements comprehensive, production-ready CI/CD pipelines supporting both GitHub Actions and GitLab CI. These pipelines provide automated validation, security scanning, testing, and deployment across multiple environments.

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    Git Repository                           │
└────────────┬────────────────────┬────────────────────────────┘
             │                    │
             ▼                    ▼
      GitHub Actions         GitLab CI
      ─────────────         ─────────
      Workflows             Pipelines
             │                    │
             └────────┬───────────┘
                      ▼
         ┌────────────────────────┐
         │  CI/CD Processing     │
         │  ─────────────────    │
         │  Validate             │
         │  Scan                 │
         │  Test                 │
         │  Plan                 │
         └────────────┬──────────┘
                      ▼
         ┌────────────────────────┐
         │  Deployment Target     │
         │  ─────────────────    │
         │  Dev (auto)            │
         │  QA (manual/auto)      │
         │  Prod (manual/approval)│
         └────────────────────────┘
```

## GitHub Actions Workflows

### 1. Pull Request Validation (`pull-request-validation.yml`)

Triggered on pull requests to validate all changes before merge.

**Stages:**
- **Metadata**: Gather PR information and changed files
- **Lint**: TFLint, Terraform format, code style
- **Validate**: Terraform validation across all environments
- **Security Scan**: tfsec, Checkov, cost estimation
- **Kubernetes**: Manifest validation with kubeconform
- **Test**: Python script tests with coverage
- **Plan**: Terraform plan for dev and qa environments
- **Quality Gate**: Enforce minimum standards

**Example Usage:**
```bash
# Triggered automatically on PR open/update
git push origin feature-branch
```

### 2. Production Deployment (`deploy-production.yml`)

Manages deployment to production with approval gates and safety checks.

**Key Features:**
- Pre-deployment validation
- Drift detection
- Multi-stage deployment (dev   qa   prod)
- Automatic rollback on failure
- Deployment status tracking
- Smoke tests and health checks

**Manual Trigger:**
```bash
# Via GitHub Actions UI or API
gh workflow run deploy-production.yml \
  -f environment=prod \
  -f terraform-action=apply \
  -f skip-approval=false
```

### 3. Container Build and Push (`container-build-push.yml`)

Builds, scans, and pushes container images to registry.

**Features:**
- Multi-image parallel builds
- Security scanning (Trivy)
- SBOM generation (Syft)
- Image signing (Cosign)
- Registry push with authentication

**Triggering:**
```yaml
on:
  push:
    branches: [main, develop]
    tags: ['v*']
    paths: ['build/**']
```

### 4. Drift Detection (`drift-detection.yml`)

Scheduled infrastructure drift detection and remediation.

**Schedule:**
- Every 6 hours (automatic)
- Manual trigger available

**Actions on Drift:**
- Creates GitHub issue for tracking
- Auto-reconciles non-prod environments
- Creates PR for production drift
- Generates detailed reports

### 5. Scheduled Compliance (`scheduled-compliance.yml`)

Weekly and monthly comprehensive security audits.

**Scans Performed:**
- Terraform security (tfsec, Checkov)
- Container image vulnerability scan
- Dependency vulnerability check
- Cost analysis and optimization
- Policy compliance (OPA/Gatekeeper)
- Kubernetes hardening (kube-bench)

## GitLab CI Pipeline

### Configuration Structure

```
.gitlab-ci.yml                 # Main configuration
  ├── Includes:
  │   ├── .gitlab/ci/terraform.yml
  │   ├── .gitlab/ci/security.yml
  │   ├── .gitlab/ci/containers.yml
  │   └── .gitlab/ci/kubernetes.yml
  └── Stages:
      ├── validate
      ├── scan
      ├── plan
      ├── deploy
      ├── verify
      └── cleanup
```

### Pipeline Stages

#### 1. Validate Stage

- **validate:format** - Terraform format checking
- **validate:terraform** - Terraform validation (parallel for dev/qa/prod)
- **validate:kubernetes** - Kubernetes manifest validation
- **validate:python** - Python script testing

#### 2. Scan Stage

- **scan:tfsec** - Terraform security scanning
- **scan:checkov** - Policy as code checks
- **scan:kubernetes** - OPA/Conftest policies
- **scan:kube-bench** - Kubernetes hardening

#### 3. Plan Stage

- **plan:sandbox** - MR sandbox environment planning
- **plan:dev** - Development environment planning
- **plan:qa** - QA environment planning

#### 4. Deploy Stage

- **deploy:sandbox** - MR sandbox deployment (manual)
- **deploy:dev** - Development deployment (manual/scheduled)
- **deploy:qa** - QA deployment (manual)
- **deploy:prod** - Production deployment (manual with approval)

#### 5. Verify Stage

- **verify:health-check** - HTTP health endpoint checks
- **verify:argocd** - ArgoCD application sync verification

#### 6. Cleanup Stage

- **destroy:sandbox** - Sandbox environment destruction

## GitHub Actions Composite Actions

Reusable components for workflow composition:

### setup-aws-credentials
Configures AWS credentials using OIDC token exchange.

```yaml
uses: ./.github/actions/setup-aws-credentials
with:
  role-arn: ${{ secrets.AWS_IAM_ROLE_ARN }}
  aws-region: us-east-1
```

### terraform-setup
Installs Terraform with plugin caching.

```yaml
uses: ./.github/actions/terraform-setup
with:
  terraform-version: '1.7.5'
  working-directory: terraform
  cache-terraform: 'true'
```

### terraform-security-scan
Runs comprehensive security scans on Terraform code.

```yaml
uses: ./.github/actions/terraform-security-scan
with:
  terraform-directory: terraform
  severity-level: MEDIUM
  infracost-api-key: ${{ secrets.INFRACOST_API_KEY }}
```

### terraform-plan
Executes Terraform plan and manages artifacts.

```yaml
uses: ./.github/actions/terraform-plan
with:
  working-directory: terraform/environments/dev
  artifact-name: tfplan-dev
```

### kubernetes-validate
Validates Kubernetes manifests with multiple tools.

```yaml
uses: ./.github/actions/kubernetes-validate
with:
  manifests-path: kubernetes
  kubernetes-version: '1.28.0'
  strict-mode: 'true'
```

### container-build
Builds and pushes container images with scanning.

```yaml
uses: ./.github/actions/container-build
with:
  image-name: my-app
  registry: ghcr.io
  dockerfile: Dockerfile
  build-context: .
  push: 'true'
  scan-image: 'true'
```

## Environment Configuration

### Secrets Required

**GitHub Actions:**
```
AWS_IAM_ROLE_ARN              # AWS role for OIDC
INFRACOST_API_KEY             # Cost estimation
SLACK_WEBHOOK_URL             # Notifications
GITHUB_TOKEN                  # Included automatically
```

**GitLab CI:**
```
AWS_ROLE_ARN                  # AWS role for OIDC
KUBECONFIG_CONTENT            # Base64-encoded kubeconfig
ARGOCD_SERVER_URL             # ArgoCD server
ARGOCD_AUTH_TOKEN             # ArgoCD authentication
HARBOR_REGISTRY               # Harbor registry URL
HARBOR_USERNAME               # Harbor authentication
HARBOR_PASSWORD               # Harbor authentication
CI_REGISTRY_PASSWORD          # GitLab container registry
```

### Branch Protections

```yaml
main:
  required_status_checks:
    - pull-request-validation
    - quality-gate
  required_approvals: 1
  dismiss_stale_reviews: true

develop:
  required_status_checks:
    - pull-request-validation
  require_code_owner_review: true
```

## Deployment Strategy

### Non-Production (Dev/QA)

```
PR/Commit   Validate   Scan   Plan   Deploy (Auto/Manual)
```

- **Dev**: Auto-deploy on develop branch
- **QA**: Manual approval required on main branch

### Production

```
PR/Commit   Validate   Scan   Plan   Drift Check   Deploy (Manual)   Verify
```

- Requires manual approval via environment protection rules
- Automatic rollback on deployment failure
- Health checks and smoke tests post-deployment
- Drift detection and reconciliation

## Security Features

### Authentication & Authorization

- **OIDC**: Keyless authentication for AWS
- **Environment Protection Rules**: Required approvals for production
- **Code Owner Review**: Required for sensitive changes
- **Branch Protection**: Enforced review and status checks

### Scanning & Compliance

- **SAST**: tfsec, Checkov, TFLint for Terraform
- **Container Security**: Trivy, kube-bench, kubeval
- **Dependency Scanning**: Dependabot, Safety, Bandit
- **Policy Enforcement**: OPA/Conftest for compliance
- **Cost Analysis**: Infracost for budget control

### Supply Chain Security

- **SBOM Generation**: Syft for container images
- **Image Signing**: Cosign for image authentication
- **Signature Verification**: Validate image provenance
- **Artifact Management**: Secure storage and retention

## Monitoring & Observability

### Metrics Tracked

- Deployment frequency
- Lead time for changes
- Change failure rate
- Mean time to recovery (MTTR)
- Build success/failure rates
- Security scan results
- Cost trends

### Notifications

- **Slack**: Deployment status updates
- **GitHub**: PR comments with plan/scan results
- **GitLab**: Pipeline status notifications
- **Issues**: Created for drift, compliance violations

## Troubleshooting

### Common Issues

**1. Terraform Lock Timeout**
```bash
# Manually unlock state
terraform force-unlock <LOCK_ID>
```

**2. AWS OIDC Token Expired**
```bash
# Check OIDC provider trust relationship
aws iam list-open-id-connect-providers
```

**3. Container Build Failures**
```bash
# Check Docker buildkit
docker buildx ls
docker buildx create --name buildkit
```

**4. State Drift Detected**
```bash
# Auto-reconcile (non-prod)
git merge drift-reconciliation-pr

# Manual reconciliation (prod)
terraform refresh
terraform apply
```

## Best Practices

### Pipeline Design

- Keep workflows focused and single-purpose
- Use matrix strategies for parallel execution
- Cache dependencies for faster builds
- Implement proper error handling and retries
- Archive artifacts with appropriate retention

### Security

- Never commit secrets to repository
- Use OIDC for cloud authentication
- Enable branch protection with required checks
- Rotate credentials regularly
- Scan all artifacts and dependencies

### Cost Optimization

- Use spot instances for non-prod environments
- Implement automatic resource cleanup
- Monitor and optimize container sizes
- Set up cost alerts and budgets
- Right-size infrastructure regularly

### Maintenance

- Keep tools and dependencies updated
- Review and optimize workflows quarterly
- Monitor failure rates and improve
- Document custom configurations
- Test disaster recovery procedures

## References

- [GitHub Actions Documentation](https://docs.github.com/en/actions)
- [GitLab CI/CD Documentation](https://docs.gitlab.com/ee/ci/)
- [Terraform Best Practices](https://www.terraform.io/cloud-docs/recommended-practices)
- [Kubernetes Security](https://kubernetes.io/docs/concepts/security/)
- [Container Security](https://docs.docker.com/engine/security/)
