# Configuration Reference (config/platform.yaml)

Top‑level
- `envs.<env>`: per‑environment settings (dev/qa/prod). Keys:
  - `alerts`: email list, Slack workspace/channel, optional PagerDuty service key SSM path
  - `budgets`: `amount`, `currency`, `thresholds`, `billing_alarm_threshold`
  - `monitoring`: Alertmanager secret path; Grafana dashboards; alarms (ALB/WAF/RDS/Redis)
  - `kubeflow`: enable + host + ACM cert + OIDC + Pipelines S3 bucket/KMS
  - `functions`: list of Lambda functions (name/package/runtime/handler/http_api/env)
- `edge`: (optional) per env CloudFront settings and function list

Example snippet
```
envs:
  dev:
    alerts: { emails: ["dev@example.com"], slack: { workspace_id: "...", channel_id: "..." } }
    budgets: { amount: 500, currency: USD, thresholds: [80,95,100], billing_alarm_threshold: 450 }
    monitoring:
      alertmanager_secret_name: "/dev/alertmanager/config"
      grafana: { dashboard_ids: ["1860:latest"] }
      alb_alarms:
        - { service: argocd, lb_full_name: "app/argocd-dev/xxxxxxxx", elb_5xx_threshold: 5, elb_5xx_period: 60, elb_5xx_evals: 3, latency_threshold: 1.0, latency_stat: p95, latency_period: 60, latency_evals: 3 }
    functions:
      - { name: hello-dev, package: hello, runtime: python3.12, handler: handler.handler, http_api: { enabled: true, routes: ["GET /"] } }
```

Notes
- Replace `lb_full_name` with the ALB full name from the AWS console.
- Keep secrets (PagerDuty, Dex clientSecret) in AWS SSM/Secrets Manager; only refer to paths/ARNs here.
