# Features & Flags

There are two ways to turn features on/off:
- Terraform vars (enable_… flags in `terraform/environments/<env>/variables.tf`)
- Config file toggles in `config/platform.yaml` under `envs.<env>.features` (loader output `module.config.features`).

Recommendation: keep TF vars as the source of truth and optionally mirror them in `config/platform.yaml`. You can wire locals to OR them together if you prefer config‑driven toggles.

Example (config/platform.yaml):

envs:
  dev:
    features:
      infrastructure:
        eks: true
        karpenter: true
        vpc_endpoints: true
      serving:
        kserve: false
        apigw: true
      observability:
        alb_alarms: true
        tg_alarms: true
        s3_alarms: true

Mapping (wired set)
- infrastructure.eks   always enabled via cluster_factory
- infrastructure.karpenter   `enable_karpenter`
- serving.kserve   `enable_kserve`
- serverless.lambda   `enable_functions`
- observability.alb_alarms   `enable_alb_alarms`
- observability.tg_alarms   `enable_tg_alarms`
- observability.s3_alarms   `enable_s3_alarms`
- security.guardduty/securityhub   `enable_security_services`

Extend this file with new categories and mirror to TF flags as you add modules (MSK, EMR, AMP, AMG, Kubecost, etc.).
