#!/bin/bash
# Validate CI/CD Pipeline Configuration
# This script performs pre-commit validation of pipeline configurations

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Counters
PASS=0
FAIL=0
WARN=0

# Helper functions
log_pass() {
    echo -e "${GREEN}✓${NC} $1"
    ((PASS++))
}

log_fail() {
    echo -e "${RED}✗${NC} $1"
    ((FAIL++))
}

log_warn() {
    echo -e "${YELLOW}⚠${NC} $1"
    ((WARN++))
}

# Validate GitHub Actions workflows
validate_github_actions() {
    echo "Validating GitHub Actions workflows..."

    local workflow_dir="${PROJECT_ROOT}/.github/workflows"

    if [ ! -d "$workflow_dir" ]; then
        log_fail "Workflows directory not found: $workflow_dir"
        return 1
    fi

    # Check for required workflows
    local required_workflows=(
        "pull-request-validation.yml"
        "deploy-production.yml"
        "container-build-push.yml"
        "drift-detection.yml"
        "scheduled-compliance.yml"
    )

    for workflow in "${required_workflows[@]}"; do
        if [ -f "$workflow_dir/$workflow" ]; then
            log_pass "Found workflow: $workflow"

            # Basic YAML validation
            if command -v yq &> /dev/null; then
                yq eval "." "$workflow_dir/$workflow" > /dev/null 2>&1 && \
                    log_pass "Valid YAML: $workflow" || \
                    log_fail "Invalid YAML in: $workflow"
            fi
        else
            log_fail "Missing required workflow: $workflow"
        fi
    done

    # Check composite actions
    local actions_dir="${PROJECT_ROOT}/.github/actions"
    local required_actions=(
        "setup-aws-credentials"
        "terraform-setup"
        "terraform-security-scan"
        "terraform-plan"
        "kubernetes-validate"
        "container-build"
    )

    echo "Validating composite actions..."
    for action in "${required_actions[@]}"; do
        if [ -f "$actions_dir/$action/action.yml" ]; then
            log_pass "Found action: $action"
        else
            log_fail "Missing required action: $action"
        fi
    done
}

# Validate GitLab CI configuration
validate_gitlab_ci() {
    echo "Validating GitLab CI configuration..."

    local gitlab_ci="${PROJECT_ROOT}/.gitlab-ci.yml"

    if [ ! -f "$gitlab_ci" ]; then
        log_fail "GitLab CI file not found: $gitlab_ci"
        return 1
    fi

    log_pass "Found GitLab CI configuration"

    # Validate YAML syntax
    if command -v yq &> /dev/null; then
        yq eval "." "$gitlab_ci" > /dev/null 2>&1 && \
            log_pass "Valid YAML syntax" || \
            log_fail "Invalid YAML in: $gitlab_ci"
    fi

    # Check for required stages
    local required_stages=("validate" "scan" "plan" "deploy" "verify")
    for stage in "${required_stages[@]}"; do
        if grep -q "^stages:" "$gitlab_ci" && grep -A 10 "^stages:" "$gitlab_ci" | grep -q "$stage"; then
            log_pass "Found stage: $stage"
        else
            log_warn "Missing stage: $stage"
        fi
    done

    # Check for required jobs
    local required_jobs=("validate:format" "plan:sandbox" "deploy:sandbox" "destroy:sandbox")
    for job in "${required_jobs[@]}"; do
        if grep -q "^$job:" "$gitlab_ci"; then
            log_pass "Found job: $job"
        else
            log_warn "Missing job: $job"
        fi
    done

    # Check for include files
    echo "Validating include files..."
    local include_files=(
        ".gitlab/ci/terraform.yml"
        ".gitlab/ci/security.yml"
        ".gitlab/ci/containers.yml"
        ".gitlab/ci/kubernetes.yml"
    )

    for include_file in "${include_files[@]}"; do
        if [ -f "$PROJECT_ROOT/$include_file" ]; then
            log_pass "Found include file: $include_file"
        else
            log_warn "Missing include file: $include_file"
        fi
    done
}

# Validate Terraform configuration
validate_terraform() {
    echo "Validating Terraform configuration..."

    if ! command -v terraform &> /dev/null; then
        log_warn "Terraform not installed, skipping validation"
        return 0
    fi

    local tf_root="${PROJECT_ROOT}/terraform"

    # Check for required directories
    local required_envs=("dev" "qa" "prod" "sandbox")
    for env in "${required_envs[@]}"; do
        if [ -d "$tf_root/environments/$env" ]; then
            log_pass "Found environment: $env"

            # Validate Terraform format
            if terraform -chdir="$tf_root/environments/$env" fmt -check -recursive 2>/dev/null; then
                log_pass "Terraform format valid: $env"
            else
                log_warn "Terraform format issues in: $env"
            fi
        else
            log_fail "Missing environment directory: $env"
        fi
    done
}

# Validate Kubernetes manifests
validate_kubernetes() {
    echo "Validating Kubernetes manifests..."

    local k8s_dir="${PROJECT_ROOT}/kubernetes"

    if [ ! -d "$k8s_dir" ]; then
        log_warn "Kubernetes directory not found"
        return 0
    fi

    # Count YAML files
    local yaml_count=$(find "$k8s_dir" -name "*.yaml" -o -name "*.yml" | wc -l)
    if [ $yaml_count -gt 0 ]; then
        log_pass "Found $yaml_count Kubernetes manifest files"
    else
        log_warn "No Kubernetes manifest files found"
    fi

    # Check for kustomization
    if find "$k8s_dir" -name "kustomization.yaml" | grep -q .; then
        log_pass "Found kustomization.yaml files"
    else
        log_warn "No kustomization.yaml found"
    fi
}

# Validate secrets configuration
validate_secrets() {
    echo "Validating secrets configuration..."

    # Check for .env files (should not be committed)
    if [ -f "${PROJECT_ROOT}/.env" ]; then
        log_fail ".env file found in repository (should be in .gitignore)"
    else
        log_pass ".env file not in repository"
    fi

    # Check .gitignore for sensitive patterns
    local gitignore="${PROJECT_ROOT}/.gitignore"
    if [ -f "$gitignore" ]; then
        if grep -q "\.env" "$gitignore" && grep -q "*.tfvars" "$gitignore"; then
            log_pass "Sensitive files configured in .gitignore"
        else
            log_warn "Consider adding .env and *.tfvars to .gitignore"
        fi
    else
        log_warn ".gitignore file not found"
    fi

    # Check for hardcoded secrets in workflows
    echo "Scanning for hardcoded secrets in workflows..."
    local secrets_found=0

    for file in $(find "${PROJECT_ROOT}/.github/workflows" -name "*.yml" 2>/dev/null); do
        if grep -E "(password|secret|key|token|credential)" "$file" | grep -v "^\s*#"; then
            if ! grep -q "secrets\." "$file"; then
                log_warn "Potential hardcoded secret in: $(basename $file)"
                ((secrets_found++))
            fi
        fi
    done

    if [ $secrets_found -eq 0 ]; then
        log_pass "No hardcoded secrets detected in workflows"
    fi
}

# Validate documentation
validate_documentation() {
    echo "Validating documentation..."

    local required_docs=(
        "docs/CI_CD_PIPELINES.md"
        ".github/DEPLOYMENT_GUIDE.md"
        ".github/PIPELINE_ARCHITECTURE.md"
    )

    for doc in "${required_docs[@]}"; do
        if [ -f "$PROJECT_ROOT/$doc" ]; then
            log_pass "Found documentation: $doc"

            # Check for minimum content
            if [ $(wc -l < "$PROJECT_ROOT/$doc") -gt 50 ]; then
                log_pass "Documentation has sufficient content: $doc"
            else
                log_warn "Documentation may be incomplete: $doc"
            fi
        else
            log_fail "Missing documentation: $doc"
        fi
    done
}

# Validate pipeline integration
validate_integration() {
    echo "Validating pipeline integration..."

    # Check for required environment variables
    echo "Checking for required secrets/variables..."
    local github_actions_file="${PROJECT_ROOT}/.github/workflows/pull-request-validation.yml"

    if grep -q "AWS_IAM_ROLE_ARN" "$github_actions_file"; then
        log_pass "Found AWS_IAM_ROLE_ARN reference"
    else
        log_warn "Missing AWS_IAM_ROLE_ARN reference"
    fi

    # Check for branch protection configuration
    if [ -f "${PROJECT_ROOT}/.github/branch-protection.yml" ]; then
        log_pass "Found branch protection configuration"
    else
        log_warn "No branch protection configuration found (optional)"
    fi

    # Check for renovate/dependabot configuration
    if [ -f "${PROJECT_ROOT}/.renovaterc.json" ] || [ -f "${PROJECT_ROOT}/.dependabot.yml" ]; then
        log_pass "Found dependency update configuration"
    else
        log_warn "No automated dependency update configuration (consider adding)"
    fi
}

# Generate report
generate_report() {
    echo ""
    echo "============================================"
    echo "Pipeline Validation Report"
    echo "============================================"
    echo -e "Passed: ${GREEN}$PASS${NC}"
    echo -e "Failed: ${RED}$FAIL${NC}"
    echo -e "Warnings: ${YELLOW}$WARN${NC}"
    echo "============================================"

    if [ $FAIL -eq 0 ]; then
        echo -e "${GREEN}All critical validations passed!${NC}"
        return 0
    else
        echo -e "${RED}Some critical validations failed!${NC}"
        return 1
    fi
}

# Main execution
main() {
    echo "Starting CI/CD Pipeline Validation..."
    echo "Project Root: $PROJECT_ROOT"
    echo ""

    validate_github_actions
    echo ""
    validate_gitlab_ci
    echo ""
    validate_terraform
    echo ""
    validate_kubernetes
    echo ""
    validate_secrets
    echo ""
    validate_documentation
    echo ""
    validate_integration
    echo ""

    generate_report
}

main "$@"
