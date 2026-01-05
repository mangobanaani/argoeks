# Multi‑Region HA (prod)

- Two regional fleets (primary/secondary) with their own hub clusters.
- Private DNS associated to all VPCs for consistent `*.prod.eks.internal` names.
- Thanos S3 buckets in both regions; replication from primary to secondary.
- Argo CD and observability deployed in both regions; same hostnames via Route53 weighted/failover records (internal).

Enable
- Set `enable_multi_region=true` and define `primary_region`, `secondary_region`, `base_cidr_*` in `terraform/environments/prod/variables.tf`.

Failover patterns
- Use Route53 failover routing with CloudWatch alarms based on ALB TargetResponseTime / HealthyHostCount.
- Ensure write flows (e.g., metrics, artifacts) are replicated or use multi‑region storage patterns.
