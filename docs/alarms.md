# Alarms Catalog

Configured from `config/platform.yaml` under `envs.<env>.monitoring`.

ALB
- Keys: `alb_alarms` (dev/qa), `alb_alarms_primary/secondary` (prod)
- Thresholds: `elb_5xx_*`, `target_5xx_*`, `latency_*` (supports p95/p99)

Target groups
- Keys: `target_group_alarms` (dev/qa), `target_group_alarms_primary/secondary` (prod)
- Provide `lb_full_name` and `tg_full_name`; thresholds: `healthy_min`, `unhealthy_max`, plus `period`, `evals`.

RDS
- Defaults per env; override via `monitoring.rds_alarms` (period, evals, cpu, storage, memory, latency, connections)

Redis (ElastiCache)
- Defaults per env; override via `monitoring.redis_alarms` (cpu, freeable_memory, evictions)

WAF
- Keys: `waf_alarms` (dev/qa) or `_primary/_secondary` (prod); set WebACL names and blocked thresholds

AWS Budgets & Billing
- Budgets: `envs.<env>.budgets.amount|currency|thresholds`
- Billing alarm: `billing_alarm_threshold` (per month)

Notifications
- All alarms publish to the env SNS topic (email + Slack Chatbot).

Findings to SNS
- EventBridge rules send Security Hub (HIGH/CRITICAL) and GuardDuty (severity ≥7) findings to the env SNS topic.

S3 buckets
- Keys: `s3_alarms`, `s3_alarms_primary/secondary` (prod). Metrics require S3 request metrics (Terraform enables whole‑bucket metrics when present in config).
- Alarms: `5xxErrors` absolute threshold; `4xx` rate (% of `AllRequests`).
