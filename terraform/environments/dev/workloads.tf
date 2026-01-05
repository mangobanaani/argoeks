module "feast_storage" {
  source      = "../../modules/feast/storage"
  count       = var.enable_feast && var.enable_feast_dynamodb && var.enable_feast_s3 && var.feast_offline_bucket != "" ? 1 : 0
  table_name  = var.feast_online_table_name
  bucket_name = var.feast_offline_bucket
}

# Feast IRSA and Kubeflow IRSA - Moved to ml-workloads.tf

module "kserve_tenant_irsa" {
  source          = "../../modules/iam/irsa_s3_tenants"
  count           = var.enable_kserve && length(var.kserve_tenants) > 0 ? 1 : 0
  oidc_issuer_url = data.aws_eks_cluster.hub.identity[0].oidc[0].issuer
  tenants         = var.kserve_tenants
}


module "lambda_functions" {
  for_each        = (var.enable_functions || try(module.config.features.serverless.lambda, false)) ? { for f in try(module.config.functions, []) : f.name => f } : {}
  source          = "../../modules/functions/lambda_function"
  name            = each.value.name
  artifact_path   = "${path.root}/../../../functions/dist/${each.value.package}.zip"
  runtime         = try(each.value.runtime, "python3.12")
  handler         = try(each.value.handler, "handler.handler")
  memory_size     = try(each.value.memory, 256)
  timeout         = try(each.value.timeout, 10)
  architectures   = try(each.value.architectures, ["x86_64"])
  environment     = try(each.value.env, {})
  create_http_api = try(each.value.http_api.enabled, false)
  http_routes     = try(each.value.http_api.routes, ["GET /"])
}

# Optional: RDS Postgres in hub VPC

module "rds_postgres" {
  source                = "../../modules/db/rds_postgres"
  count                 = var.enable_rds_postgres ? 1 : 0
  name                  = "dev-mlops-postgres"
  vpc_id                = module.cluster_factory.vpc_ids[module.cluster_factory.cluster_names[0]]
  subnet_ids            = module.cluster_factory.private_subnets[module.cluster_factory.cluster_names[0]]
  vpc_cidr              = "10.0.0.0/8"
  instance_class        = var.rds_instance_class
  backup_retention_days = var.rds_backup_retention
  skip_final_snapshot   = var.rds_skip_final_snapshot
  existing_secret_arn   = var.rds_existing_secret_arn
}

# Optional: ElastiCache Redis in hub VPC

module "redis" {
  source                   = "../../modules/cache/elasticache_redis"
  count                    = var.enable_redis ? 1 : 0
  name                     = "dev-mlops-redis"
  vpc_id                   = module.cluster_factory.vpc_ids[module.cluster_factory.cluster_names[0]]
  subnet_ids               = module.cluster_factory.private_subnets[module.cluster_factory.cluster_names[0]]
  vpc_cidr                 = "10.0.0.0/8"
  existing_auth_secret_arn = var.redis_existing_auth_secret_arn
}


module "aurora" {
  source                 = "../../modules/db/aurora"
  count                  = var.enable_aurora ? 1 : 0
  name                   = "dev-aurora"
  engine                 = var.aurora_engine
  engine_version         = var.aurora_engine_version
  database_name          = var.aurora_db_name
  username               = var.aurora_username
  vpc_id                 = module.cluster_factory.vpc_ids[module.cluster_factory.cluster_names[0]]
  subnet_ids             = module.cluster_factory.private_subnets[module.cluster_factory.cluster_names[0]]
  vpc_cidr               = "10.0.0.0/8"
  kms_key_id             = null
  serverless_v2          = var.aurora_serverless_v2
  min_acu                = var.aurora_min_acu
  max_acu                = var.aurora_max_acu
  instance_class         = var.aurora_instance_class
  instances              = var.aurora_instances
  create_password_secret = var.aurora_create_password_secret
  secret_name            = var.aurora_secret_name
}

# Optional: MSK cluster in hub VPC

module "msk" {
  source                 = "../../modules/data/msk"
  count                  = var.enable_msk ? 1 : 0
  name                   = "dev-msk"
  kafka_version          = "3.6.0"
  number_of_broker_nodes = 3
  broker_instance_type   = "kafka.m5.large"
  vpc_id                 = module.cluster_factory.vpc_ids[module.cluster_factory.cluster_names[0]]
  subnet_ids             = module.cluster_factory.private_subnets[module.cluster_factory.cluster_names[0]]
  security_group_ids     = []
}

module "kuberay_operator" {
  source = "../../modules/kuberay/operator"
  count  = var.enable_kuberay ? 1 : 0
  providers = {
    kubernetes = kubernetes.hub
    helm       = helm.hub
  }
}

module "kubecost" {
  source  = "../../modules/cost/kubecost"
  count   = var.enable_kubecost ? 1 : 0
  install = true
  values  = [yamlencode({
    global = {
      clusterId = module.cluster_factory.cluster_names[0]
    }
    persistentVolume = {
      storageClass = "gp2"
    }
    prometheus = {
      server = {
        persistentVolume = {
          storageClass = "gp2"
        }
      }
    }
  })]

  providers = {
    kubernetes = kubernetes.hub
    helm       = helm.hub
  }
}


module "irsa_rds_connect" {
  source          = "../../modules/iam/irsa_rds_connect"
  count           = var.enable_rds_postgres && var.enable_rds_iam_irsa ? 1 : 0
  name            = "dev-mlops-rds-connect"
  namespace       = var.rds_iam_sa_namespace
  service_account = var.rds_iam_sa_name
  oidc_issuer_url = data.aws_eks_cluster.hub.identity[0].oidc[0].issuer
  rds_resource_id = module.rds_postgres[0].resource_id
  db_username     = "mlops"
}

module "ml_workloads_irsa" {
  source = "../../modules/iam/irsa_ml_workloads"

  environment     = local.environment
  oidc_issuer_url = local.oidc_issuer_url

  workloads = concat(
    # vLLM for inference
    var.enable_vllm_sa_irsa && var.vllm_bucket_arn != "" ? [{
      name                   = "vllm"
      namespace              = var.vllm_namespace
      service_account        = var.vllm_sa_name
      create_namespace       = true
      create_service_account = true
      s3_access = {
        bucket_arns  = [var.vllm_bucket_arn]
        kms_key_arns = var.vllm_kms_arn != "" ? [var.vllm_kms_arn] : []
        read_only    = false
      }
    }] : [],

    # Triton for inference
    var.enable_triton_sa_irsa && var.triton_bucket_arn != "" ? [{
      name                   = "triton"
      namespace              = var.triton_namespace
      service_account        = var.triton_sa_name
      create_namespace       = true
      create_service_account = true
      s3_access = {
        bucket_arns  = [var.triton_bucket_arn]
        kms_key_arns = var.triton_kms_arn != "" ? [var.triton_kms_arn] : []
        read_only    = false
      }
    }] : [],

    # Kubeflow Pipelines
    var.enable_kubeflow && var.kubeflow_pipeline_bucket_arn != "" ? [{
      name                   = "kubeflow-pipelines"
      namespace              = var.kubeflow_namespace
      service_account        = var.kubeflow_sa_name
      create_service_account = true
      s3_access = {
        bucket_arns  = [var.kubeflow_pipeline_bucket_arn]
        kms_key_arns = var.kubeflow_pipeline_kms_arn != "" ? [var.kubeflow_pipeline_kms_arn] : []
        read_only    = false
      }
    }] : [],

    # MLflow artifacts (if using separate IRSA)
    var.enable_mlflow_irsa && var.mlflow_artifacts_bucket_arn != "" ? [{
      name                   = "mlflow"
      namespace              = var.mlflow_namespace
      service_account        = var.mlflow_service_account
      create_service_account = true
      s3_access = {
        bucket_arns  = [var.mlflow_artifacts_bucket_arn]
        kms_key_arns = var.mlflow_artifacts_kms_arn != "" ? [var.mlflow_artifacts_kms_arn] : []
        read_only    = false
      }
      rds_access = var.enable_rds_postgres ? {
        resource_id = module.rds_postgres[0].resource_id
        username    = "mlflow"
      } : null
    }] : [],

    # Feast (if using IRSA - split into online/offline handled by separate SAs)
    var.enable_feast && var.enable_feast_irsa && var.enable_feast_s3 && var.feast_offline_bucket != "" ? [{
      name                   = "feast-offline"
      namespace              = var.feast_namespace
      service_account        = var.feast_sa_offline
      create_service_account = true
      s3_access = {
        bucket_arns  = [module.feast_storage[0].bucket_arn]
        kms_key_arns = []
        read_only    = false
      }
    }] : []
  )

  tags = local.common_tags

  providers = {
    kubernetes = kubernetes.hub
  }
}

# Feast online (DynamoDB) - separate module since irsa_ml_workloads handles it
module "irsa_feast_online" {
  source = "../../modules/iam/irsa_dynamodb"

  count           = var.enable_feast && var.enable_feast_irsa && var.enable_feast_dynamodb ? 1 : 0
  name            = "dev-feast-online-irsa"
  namespace       = var.feast_namespace
  service_account = var.feast_sa_online
  oidc_issuer_url = local.oidc_issuer_url
  table_arns      = [module.feast_storage[0].table_arn]
  read_only       = false
}
