AWS_PROFILE ?=
REGION ?= us-east-1
ENV ?= dev

# Colors
BLUE := \033[0;34m
GREEN := \033[0;32m
YELLOW := \033[1;33m
RED := \033[0;31m
NC := \033[0m

.PHONY: help init plan apply destroy fmt generate-flux

## help: Show this help message
help:
	@echo "$(BLUE)ArgoEKS Terraform Makefile$(NC)"
	@echo ""
	@echo "$(GREEN)Quick Start:$(NC)"
	@echo "  1. source .env                    - Load AWS credentials"
	@echo "  2. make plan ENV=dev              - Plan dev environment"
	@echo "  3. make apply ENV=dev             - Apply dev environment"
	@echo ""
	@echo "$(GREEN)Environment Commands:$(NC)"
	@echo "  make init ENV=<env>               - Initialize Terraform"
	@echo "  make plan ENV=<env>               - Run Terraform plan"
	@echo "  make apply ENV=<env>              - Apply changes (auto-approve)"
	@echo "  make destroy ENV=<env>            - Destroy infrastructure"
	@echo ""
	@echo "$(GREEN)Shortcuts:$(NC)"
	@echo "  make dev                          - Plan dev environment"
	@echo "  make qa                           - Plan qa environment"
	@echo "  make prod                         - Plan prod environment"
	@echo "  make sandbox                      - Plan sandbox environment"
	@echo ""
	@echo "$(GREEN)Utilities:$(NC)"
	@echo "  make fmt                          - Format Terraform files"
	@echo "  make validate ENV=<env>           - Validate configuration"
	@echo "  make output ENV=<env>             - Show outputs"
	@echo "  make clean ENV=<env>              - Clean cache"
	@echo "  make docs-status                  - Check doc freshness from docs/docs-index.yaml"
	@echo ""
	@echo "$(GREEN)Other:$(NC)"
	@echo "  make generate-flux                - Generate Flux kustomizations"
	@echo "  make package-lambda               - Package Lambda functions"
	@echo ""
	@echo "$(YELLOW)Available environments: dev, qa, prod, sandbox$(NC)"

## check-aws: Verify AWS credentials
check-aws:
	@if [ -z "$$AWS_ACCESS_KEY_ID" ] && [ -z "$$AWS_PROFILE" ]; then \
		echo "$(RED)✗ AWS credentials not set$(NC)"; \
		echo "$(YELLOW)  Run: source .env$(NC)"; \
		exit 1; \
	fi
	@echo "$(GREEN)✓ AWS credentials loaded$(NC)"

## check-env: Verify environment directory exists
check-env:
	@if [ ! -d "terraform/environments/$(ENV)" ]; then \
		echo "$(RED)✗ Environment '$(ENV)' not found$(NC)"; \
		exit 1; \
	fi
	@echo "$(GREEN)✓ Environment: $(ENV)$(NC)"

init:
	cd terraform && terraform init

plan:
	cd terraform && terraform plan -var="region=$(REGION)"

apply:
	cd terraform && terraform apply -auto-approve -var="region=$(REGION)"

destroy:
	cd terraform && terraform destroy -auto-approve -var="region=$(REGION)"

fmt:
	@echo "$(BLUE)Formatting Terraform files...$(NC)"
	cd terraform && terraform fmt -recursive

# Environment-scoped commands (dev/qa/prod/sandbox)
.PHONY: init-env plan-env apply-env destroy-env validate output clean
init-env: check-env check-aws
	@echo "$(BLUE)Initializing $(ENV)...$(NC)"
	cd terraform/environments/$(ENV) && terraform init -upgrade

plan-env: check-env check-aws init-env
	@echo "$(BLUE)Planning $(ENV)...$(NC)"
	cd terraform/environments/$(ENV) && terraform plan

apply-env: check-env check-aws init-env
	@echo "$(YELLOW)⚠ Applying changes to $(ENV)...$(NC)"
	cd terraform/environments/$(ENV) && terraform apply -auto-approve

destroy-env: check-env check-aws
	@echo "$(RED)⚠⚠⚠ DESTROYING $(ENV) ⚠⚠⚠$(NC)"
	@echo "$(RED)Type '$(ENV)' to confirm:$(NC)"
	@read -r confirm && [ "$$confirm" = "$(ENV)" ] || (echo "Aborted" && exit 1)
	cd terraform/environments/$(ENV) && terraform destroy

validate: check-env
	@echo "$(BLUE)Validating $(ENV)...$(NC)"
	cd terraform/environments/$(ENV) && terraform validate

output: check-env
	@echo "$(BLUE)Outputs for $(ENV):$(NC)"
	cd terraform/environments/$(ENV) && terraform output

clean: check-env
	@echo "$(YELLOW)Cleaning $(ENV) cache...$(NC)"
	rm -rf terraform/environments/$(ENV)/.terraform
	rm -f terraform/environments/$(ENV)/.terraform.lock.hcl
	@echo "$(GREEN)✓ Cleaned$(NC)"

# Environment shortcuts
dev:
	@$(MAKE) plan-env ENV=dev

qa:
	@$(MAKE) plan-env ENV=qa

prod:
	@$(MAKE) plan-env ENV=prod

sandbox:
	@$(MAKE) plan-env ENV=sandbox

# Generate Flux Kustomizations; override FILE and OUT as needed
FILE ?= configuration/clusters/clusters.yaml
OUT ?= kubernetes/gitops/flux/generated
SANDBOX_NAME ?= sandbox-$(USER)
SANDBOX_SOURCE ?= dev
SANDBOX_TTL ?= 8
generate-flux:
	bash automation/scripts/setup/generate-flux-kustomizations.sh $(FILE) $(OUT)

.PHONY: render-alerts
render-alerts:
	bash automation/scripts/utils/render-alerts-from-config.sh configuration/platform.yaml

.PHONY: render-grafana-dashboards
render-grafana-dashboards:
	bash automation/scripts/utils/render-grafana-dashboards.sh configuration/platform.yaml

.PHONY: render-kubeflow
render-kubeflow:
	bash automation/scripts/utils/render-kubeflow-from-config.sh configuration/platform.yaml $(ENV)

.PHONY: package-lambda
package-lambda:
	bash automation/scripts/utils/package-lambda.sh

.PHONY: standardize-modules
standardize-modules:
	bash automation/scripts/dev/standardize-modules.sh

.PHONY: cli
cli:
	python3 automation/scripts/argoeks.py --help

.PHONY: cli-test
cli-test:
	python3 -m pytest automation/scripts/tests -v

.PHONY: sandbox-create
sandbox-create:
	bash automation/scripts/dev/sandbox-env.sh create --name $(SANDBOX_NAME) --source $(SANDBOX_SOURCE) --ttl-hours $(SANDBOX_TTL)

.PHONY: sandbox-destroy
sandbox-destroy:
	bash automation/scripts/dev/sandbox-env.sh destroy --name $(SANDBOX_NAME) --source $(SANDBOX_SOURCE)
