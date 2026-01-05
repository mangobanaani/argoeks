# Architecture Overview

- Hub‑and‑spoke: one or more management (hub) clusters running GitOps (Argo CD), Backstage (optional), and central services; 1..50 workload clusters per env.
- GitOps at scale: Argo CD ApplicationSets discover clusters and deploy platform stacks (observability, RBAC, ExternalDNS, dashboards, Kubeflow, etc.).
- Observability: per‑cluster Prometheus + Alertmanager, fleet‑level Thanos; dashboards via Grafana with sidecar.
- Security: IRSA for all controllers and apps; KMS for secrets/S3/RDS/CloudTrail; WAF on all UIs; Gatekeeper + PSA + NetPols; SecurityHub/GuardDuty/Inspector optional.
- Networking: private subnets, VPC endpoints (S3/ECR/STS/Logs), Route53 Private Hosted Zones; ALB/NLB internal; PrivateLink/VPC Lattice patterns.
- Autoscaling: EKS managed node group for bootstrap + Karpenter for workload capacity (spot/on‑demand, Arm/AMD).
- Multi‑region (prod): dual fleets in primary/secondary regions, private DNS shared, S3 Thanos bucket replication, duplicated GitOps stacks.

Data flow
- Infrastructure (Terraform)   clusters + IAM + DNS + buckets + observability + alerts.
- GitOps (Argo CD/Flux)   continuous delivery of platform and app stacks from Git.
- Metrics/logs/alerts   Prometheus/Thanos/CloudWatch/SNS/Slack/PagerDuty.

See docs/MultiRegion.md and docs/Security.md for DR and compliance details.
