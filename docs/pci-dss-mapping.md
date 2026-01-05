# PCI-DSS Control Mapping (High Level)

This repo provides opinionated scaffolding toward PCI-DSS alignment. Final compliance requires scoping, compensating controls, and auditor review.

- Network segmentation (Req. 1)
  - Private subnets, no public nodes. VPC Flow Logs enabled (`modules/logging/vpc_flow_logs`). Private Route53 zones per env.
  - ALB internal by default; PrivateLink/VPC Lattice patterns for east-west.
- Secure configurations (Req. 2)
  - Terraform as code; Gatekeeper policies for namespaces/registries/tags; Pod Security Admission enforced.
- Data protection (Req. 3–4)
  - KMS encryption for EKS secrets, S3, CloudTrail, RDS, Thanos. TLS via ALB with latest TLS policy and ACM PCA certificates.
- Access control (Req. 7–9)
  - IRSA for workload identity; Argo CD SSO + RBAC; cluster access via IAM roles (`admin_role_arns`, `readonly_role_arns`). MFA enforced outside code via IdP.
- Vulnerability management (Req. 6)
  - ECR scanning (enhanced), Inspector2 for EC2/ECR/Lambda, tfsec/Trivy/Conftest in CI.
- Logging/monitoring (Req. 10–11)
  - CloudTrail (multi-region), EKS control plane logs with retention, VPC Flow Logs, WAF/ALB logs (annotations), Thanos/Grafana central metrics.
- Change control (Req. 6, 10, 12)
  - PR-based CI/CD, sandbox preview env, required plans and policy checks.
- Regular security testing (Req. 11)
  - GuardDuty, Security Hub (FSBP, CIS, PCI standards). Optional Macie for data classification.

Consult your QSA for scope definition, quarterly scans, and evidence collection.
