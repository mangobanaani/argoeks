# Security & Compliance

Controls
- Identity: IRSA for controllers/apps; CI OIDC to AWS; cluster access via IAM roles   Kubernetes groups   RBAC.
- Encryption: KMS for EKS secrets, S3, RDS, CloudTrail; TLS via ACM PCA; ALB latest TLS policy.
- Policies: Pod Security Admission (restricted), Gatekeeper (allowed repos + no `:latest` + labels), NetPols (deny‑by‑default in platform namespaces).
- Detection: Security Hub (CIS/PCI/FSBP), GuardDuty (incl. K8s), Inspector2.
- Logging: CloudTrail (KMS + validation), VPC Flow Logs, EKS control plane logs.

How to use
- Enable security services via env vars: `enable_security_services`, `enable_cloudtrail`, `enable_vpc_flow_logs`.
- Pass admin/read‑only IAM role ARNs to map SSO groups (see README “Admin roles and RBAC”).
- Keep secrets in Secrets Manager/SSM. External Secrets Operator syncs them into clusters.

PCI/DSS
- See docs/PCI-DSS-Mapping.md for a control‑to‑implementation map.
