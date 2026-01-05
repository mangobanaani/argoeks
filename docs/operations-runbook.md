# Operations Runbook (SRE)

Common tasks
- Rotate Argo CD admin/SSO secrets: update Secret or IdP, Argo CD sync.
- Alertmanager config change: update secret in Secrets Manager   `make render-alerts`   Argo CD sync.
- Dashboards: update `config/platform.yaml` IDs   `make render-grafana-dashboards`   sync.
- Add a cluster: provision via Terraform (increase `cluster_count` or add to registry)   register in Argo CD   labels as needed.
- Sandbox envs:
  - Create: `make sandbox-create SANDBOX_NAME=sandbox-ticket123 SANDBOX_SOURCE=dev`
  - Destroy: `make sandbox-destroy SANDBOX_NAME=sandbox-ticket123`
  - Metadata lives in `terraform/environments/<name>/.sandbox-meta.json` (tracks TTL + source). Remember to clean up AWS resources if users skip destroy (check CloudTrail + `.tfstate`).

Incident hints
- High ALB 5xx/latency: check target health, look for recent deploys, examine app logs, scale via Karpenter or rollback.
- RDS/Redis memory/storage: increase instance/ACU, tune connections, purge cache, or expand storage.
- ExternalDNS failures: validate IRSA role and Route53 zone ID; check controller logs.

DR
- Prod multi‑region: Route53 failover/weighted records; validate ALB health and Thanos replication.
- Restore secrets: from AWS Secrets Manager; ESO will reconcile to clusters.
