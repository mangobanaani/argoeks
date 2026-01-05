# Observability

Components
- kube-prometheus-stack per cluster (Prometheus, Alertmanager, Grafana)
- Thanos aggregator in hub (object storage via S3 with KMS, multi‑region optional)
- Grafana dashboards via sidecar from labeled ConfigMaps
- Alerting via SNS + Slack Chatbot + Budgets/Billing alarms

Usage
- Apply observability ApplicationSet: `gitops/argocd/applicationset-observability.yaml`
- Render and sync Alertmanager ESO from config: `make render-alerts`
- Render and sync Grafana dashboards from config: `make render-grafana-dashboards`

Thanos
- Secret `thanos-objstore` holds S3 config; IRSA attaches S3/KMS access.
- In prod, buckets replicate cross‑region (if enabled).

Dashboards
- Configure IDs/revisions in `config/platform.yaml`. The fetch job downloads from grafana.com and creates labeled ConfigMaps consumed by Grafana.

Alarms
- See docs/Alarms.md for per‑service ALB, RDS, Redis, WAF, Budgets, Billing.
