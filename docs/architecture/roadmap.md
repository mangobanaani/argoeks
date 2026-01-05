#  Full MLOps/GenAI Implementation Roadmap

**Project:** argoeks MLOps Platform
**Timeline:** 6 months
**Budget:** $2,500-4,000/month operational costs
**Team Size:** 2-4 engineers

---

## PHASE 1: CRITICAL FOUNDATION (Weeks 1-2)

**Goal:** Production-ready monitoring, cost controls, state management
**New Monthly Cost:** +$160 (total: $450-650/month)

### Week 1: Observability & State Management

#### Day 1-2: S3 Backend Setup  CRITICAL
```bash
# 1. Create S3 bucket for Terraform state
aws s3 mb s3://argoeks-terraform-state --region us-east-1
aws s3api put-bucket-versioning \
  --bucket argoeks-terraform-state \
  --versioning-configuration Status=Enabled

aws s3api put-bucket-encryption \
  --bucket argoeks-terraform-state \
  --server-side-encryption-configuration '{
    "Rules": [{
      "ApplyServerSideEncryptionByDefault": {
        "SSEAlgorithm": "AES256"
      }
    }]
  }'

# 2. Create DynamoDB table for state locking
aws dynamodb create-table \
  --table-name argoeks-terraform-locks \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST \
  --region us-east-1

# 3. Update providers.tf with backend configuration
# (Instructions in terraform.tfvars line 125-145)
```

**Checklist:**
- [ ] S3 bucket created with versioning
- [ ] S3 bucket encryption enabled
- [ ] DynamoDB table created
- [ ] Backend configuration added to providers.tf
- [ ] State migrated: `terraform init -migrate-state`
- [ ] Local state files deleted

#### Day 3-4: Deploy Phase 1 Infrastructure
```bash
# 1. Update configuration
cd /Users/pekka/Documents/argoeks/terraform/environments/dev

# 2. Edit terraform.tfvars
# - Set budget_emails to your email
# - Review all Phase 1 settings

# 3. Initialize with new backend
terraform init -migrate-state

# 4. Plan deployment
terraform plan -out=phase1.tfplan

# 5. Review plan output
# Expected: ~100-120 resources to add
# - RDS PostgreSQL (for MLflow)
# - Redis (for caching)
# - Thanos stack (Prometheus + Grafana)
# - Kubecost
# - Budget alarms
# - Network policies

# 6. Deploy
terraform apply phase1.tfplan
# Estimated time: 20-25 minutes
```

**Checklist:**
- [ ] terraform.tfvars updated with your email
- [ ] terraform plan reviewed (no errors)
- [ ] Infrastructure deployed successfully
- [ ] kubeconfig updated: `aws eks update-kubeconfig --name dev-mlops-cluster-01`
- [ ] All pods running: `kubectl get pods -A`

#### Day 5: Verify Observability Stack
```bash
# 1. Check Thanos components
kubectl get pods -n monitoring
# Expected: thanos-query, thanos-store, thanos-compact, prometheus

# 2. Access Grafana
kubectl port-forward -n monitoring svc/grafana 3000:80
# Open: http://localhost:3000
# Default: admin / prom-operator

# 3. Check Prometheus targets
kubectl port-forward -n monitoring svc/prometheus-operated 9090:9090
# Open: http://localhost:9090/targets
# All targets should be UP

# 4. Verify Kubecost
kubectl port-forward -n kubecost svc/kubecost-cost-analyzer 9090:9090
# Open: http://localhost:9090
# Should show cost breakdown

# 5. Check Cilium Hubble
kubectl port-forward -n kube-system svc/hubble-ui 12000:80
# Open: http://localhost:12000
# Network flows visible
```

**Checklist:**
- [ ] Grafana accessible with dashboards
- [ ] Prometheus scraping all targets
- [ ] Kubecost showing cost data
- [ ] Hubble UI showing network flows
- [ ] CloudWatch alarms configured

### Week 2: Documentation & Runbooks

#### Day 6-7: Create Runbooks
```bash
# Create runbook directory
mkdir -p /Users/pekka/Documents/argoeks/docs/runbooks

# Runbooks to create:
# - incident-response.md
# - cost-optimization.md
# - backup-restore.md
# - scaling-playbook.md
# - security-checklist.md
```

**Checklist:**
- [ ] Incident response runbook created
- [ ] Cost optimization playbook documented
- [ ] Backup/restore procedures tested
- [ ] Scaling procedures documented
- [ ] Security checklist completed

#### Day 8-10: Setup Alerting & Monitoring
```bash
# 1. Configure Slack/email alerts
# Edit in Grafana UI or via ConfigMaps

# 2. Test budget alerts
# Should receive email at budget thresholds

# 3. Create custom dashboards
# - Cluster overview
# - Cost per namespace
# - ML workload metrics (ready for Phase 2)
# - GPU utilization (ready for Phase 3)

# 4. Setup log aggregation (optional)
helm repo add grafana https://grafana.github.io/helm-charts
helm install loki grafana/loki-stack -n monitoring
```

**Checklist:**
- [ ] Slack webhook configured (or email)
- [ ] Budget alerts tested
- [ ] Custom Grafana dashboards created
- [ ] Log aggregation deployed
- [ ] Alert rules documented

**Phase 1 Complete!**
**Budget Check:** Should be ~$450-650/month

---

## PHASE 2: MLOPS CORE (Weeks 3-10)

**Goal:** Full ML development, training, and serving platform
**New Monthly Cost:** +$750 (total: $1,200-1,800/month)

### Week 3: MLflow Deployment

#### Step 1: Enable MLflow
```hcl
# In terraform.tfvars
enable_mlflow_irsa = true
mlflow_bucket_name = ""  # Auto-generated
```

#### Step 2: Deploy MLflow
```bash
# 1. Apply Terraform changes
terraform plan -out=mlflow.tfplan
terraform apply mlflow.tfplan

# 2. Verify MLflow deployment
kubectl get pods -n mlflow
kubectl get svc -n mlflow

# 3. Access MLflow UI
kubectl port-forward -n mlflow svc/mlflow-tracking 5000:5000
# Open: http://localhost:5000

# 4. Test MLflow tracking
python3 << 'EOF'
import mlflow
mlflow.set_tracking_uri("http://localhost:5000")
mlflow.set_experiment("test-experiment")
with mlflow.start_run():
    mlflow.log_param("test", "value")
    mlflow.log_metric("accuracy", 0.95)
print("MLflow tracking works!")
EOF
```

**Checklist:**
- [ ] MLflow deployed to cluster
- [ ] MLflow UI accessible
- [ ] S3 bucket created for artifacts
- [ ] RDS database connected
- [ ] Test experiment logged
- [ ] Model registry functional

### Week 4: Data Lake Setup

#### Step 1: Create S3 Data Lake Structure
```bash
# Create data lake buckets
aws s3 mb s3://argoeks-datalake-dev-bronze --region us-east-1
aws s3 mb s3://argoeks-datalake-dev-silver --region us-east-1
aws s3 mb s3://argoeks-datalake-dev-gold --region us-east-1

# Apply lifecycle policies
aws s3api put-bucket-lifecycle-configuration \
  --bucket argoeks-datalake-dev-bronze \
  --lifecycle-configuration file://bronze-lifecycle.json

# Enable versioning
aws s3api put-bucket-versioning \
  --bucket argoeks-datalake-dev-gold \
  --versioning-configuration Status=Enabled
```

#### Step 2: Setup AWS Glue Data Catalog
```bash
# Create Glue database
aws glue create-database \
  --database-input '{
    "Name": "mlops_dev",
    "Description": "MLOps development data catalog"
  }'

# Create crawler for bronze layer
aws glue create-crawler \
  --name bronze-crawler \
  --role arn:aws:iam::ACCOUNT:role/GlueServiceRole \
  --database-name mlops_dev \
  --targets '{
    "S3Targets": [{
      "Path": "s3://argoeks-datalake-dev-bronze/"
    }]
  }'
```

**Checklist:**
- [ ] Bronze/Silver/Gold buckets created
- [ ] Lifecycle policies applied
- [ ] Glue database created
- [ ] Glue crawlers configured
- [ ] Data quality checks implemented
- [ ] Sample data ingested

### Week 5: Feast Feature Store

#### Step 1: Enable Feast
```hcl
# In terraform.tfvars
enable_feast = true
feast_offline_bucket = ""  # Auto-generated
feast_online_store   = "redis"
```

#### Step 2: Deploy Feast
```bash
# 1. Apply Terraform
terraform apply

# 2. Initialize Feast repository
feast init feast_repo
cd feast_repo

# 3. Configure feature_store.yaml
cat > feature_store.yaml << 'EOF'
project: mlops_dev
registry: s3://argoeks-datalake-dev-gold/feast/registry.db
provider: aws
online_store:
  type: redis
  connection_string: "redis-master.redis.svc.cluster.local:6379"
offline_store:
  type: file
  path: s3://argoeks-feast-offline/
EOF

# 4. Define example features
cat > features.py << 'EOF'
from feast import Entity, Feature, FeatureView, ValueType
from feast.data_source import FileSource

user = Entity(name="user_id", value_type=ValueType.INT64)

user_features = FileSource(
    path="s3://argoeks-datalake-dev-gold/user_features.parquet",
    event_timestamp_column="event_timestamp"
)

user_fv = FeatureView(
    name="user_features",
    entities=["user_id"],
    features=[
        Feature(name="age", dtype=ValueType.INT64),
        Feature(name="country", dtype=ValueType.STRING),
    ],
    online=True,
    source=user_features,
    ttl=timedelta(days=1)
)
EOF

# 5. Apply feature definitions
feast apply

# 6. Test feature retrieval
feast materialize-incremental $(date +%Y-%m-%d)
```

**Checklist:**
- [ ] Feast deployed to cluster
- [ ] Redis online store connected
- [ ] S3 offline store configured
- [ ] Example features defined
- [ ] Features materialized to online store
- [ ] Feature retrieval tested

### Week 6-7: JupyterHub & Development Environment

#### Step 1: Deploy JupyterHub
```bash
# 1. Create namespace
kubectl create namespace jupyter

# 2. Deploy JupyterHub
helm repo add jupyterhub https://jupyterhub.github.io/helm-chart/
helm upgrade --install jupyterhub jupyterhub/jupyterhub \
  --namespace jupyter \
  --values jupyterhub-values.yaml

# jupyterhub-values.yaml:
# singleuser:
#   image:
#     name: jupyter/tensorflow-notebook
#     tag: latest
#   cpu:
#     limit: 4
#     guarantee: 2
#   memory:
#     limit: 16G
#     guarantee: 8G
#   storage:
#     capacity: 100Gi
# hub:
#   config:
#     Authenticator:
#       auto_login: true
#       admin_users:
#         - admin
```

#### Step 2: Configure Development Environment
```bash
# Create custom Jupyter image with ML tools
cat > Dockerfile << 'EOF'
FROM jupyter/tensorflow-notebook:latest
USER root
RUN pip install --no-cache-dir \
    mlflow \
    feast \
    great-expectations \
    evidently \
    shap \
    optuna \
    ray[default]
USER jovyan
EOF

# Build and push to ECR
aws ecr create-repository --repository-name mlops/jupyter
docker build -t ACCOUNT.dkr.ecr.us-east-1.amazonaws.com/mlops/jupyter .
docker push ACCOUNT.dkr.ecr.us-east-1.amazonaws.com/mlops/jupyter
```

**Checklist:**
- [ ] JupyterHub deployed
- [ ] Custom image with ML tools created
- [ ] User authentication configured
- [ ] Persistent storage working
- [ ] MLflow integration tested
- [ ] Feast integration tested
- [ ] Auto-shutdown configured

### Week 8-9: Kubeflow Pipelines

#### Step 1: Enable Kubeflow
```hcl
# In terraform.tfvars
enable_kubeflow = true
```

#### Step 2: Deploy and Test Pipeline
```bash
# 1. Apply Terraform
terraform apply

# 2. Access Kubeflow UI
kubectl port-forward -n kubeflow svc/ml-pipeline-ui 8080:80

# 3. Create example pipeline
cat > simple_pipeline.py << 'EOF'
from kfp import dsl, compiler

@dsl.component
def train_model():
    import mlflow
    mlflow.log_metric("accuracy", 0.95)

@dsl.component
def deploy_model():
    print("Deploying model...")

@dsl.pipeline(name="Simple ML Pipeline")
def ml_pipeline():
    train = train_model()
    deploy = deploy_model().after(train)

compiler.Compiler().compile(ml_pipeline, 'pipeline.yaml')
EOF

# 4. Upload and run pipeline
python simple_pipeline.py
# Upload pipeline.yaml via UI
```

**Checklist:**
- [ ] Kubeflow Pipelines deployed
- [ ] Pipeline UI accessible
- [ ] Example pipeline created
- [ ] Pipeline executed successfully
- [ ] MLflow integration working
- [ ] Artifact storage configured

### Week 10: Model Serving (KServe)

#### Step 1: Enable KServe
```hcl
# In terraform.tfvars
enable_kserve = true
```

#### Step 2: Deploy First Model
```bash
# 1. Train and save model with MLflow
python << 'EOF'
import mlflow
import mlflow.sklearn
from sklearn.ensemble import RandomForestClassifier

mlflow.set_tracking_uri("http://mlflow.mlflow.svc.cluster.local:5000")
mlflow.set_experiment("production-models")

with mlflow.start_run():
    model = RandomForestClassifier()
    # ... train model ...
    mlflow.sklearn.log_model(model, "model")
    run_id = mlflow.active_run().info.run_id
print(f"Model logged: {run_id}")
EOF

# 2. Deploy model with KServe
cat > model-serving.yaml << 'EOF'
apiVersion: serving.kserve.io/v1beta1
kind: InferenceService
metadata:
  name: sklearn-iris
spec:
  predictor:
    sklearn:
      storageUri: "s3://argoeks-mlflow/artifacts/{run_id}/model"
EOF

kubectl apply -f model-serving.yaml

# 3. Test inference
curl -H "Content-Type: application/json" \
  http://sklearn-iris.default.models.dev.eks.local/v1/predict \
  -d '{"instances": [[5.1, 3.5, 1.4, 0.2]]}'
```

**Checklist:**
- [ ] KServe deployed
- [ ] Model deployed from MLflow
- [ ] Inference endpoint accessible
- [ ] Load testing completed
- [ ] Autoscaling configured
- [ ] Monitoring dashboards created

**Phase 2 Complete!**
**Budget Check:** Should be ~$1,200-1,800/month

---

## PHASE 3: LLM & GENAI (Months 4-6)

**Goal:** Production LLM serving and RAG applications
**New Monthly Cost:** +$1,300 (total: $2,500-4,000/month)

### Month 4: GPU Infrastructure & vLLM

#### Week 1-2: GPU Node Pool
```hcl
# In terraform.tfvars
enable_vllm_sa_irsa = true
vllm_bucket_name = ""

# Add GPU node configuration to Karpenter
```

```bash
# 1. Apply Terraform for GPU nodes
terraform apply

# 2. Verify GPU nodes can be provisioned
kubectl apply -f - << 'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: gpu-test
spec:
  containers:
  - name: cuda
    image: nvidia/cuda:12.0-base
    command: ["nvidia-smi"]
    resources:
      limits:
        nvidia.com/gpu: 1
EOF

kubectl logs gpu-test  # Should show GPU info
```

#### Week 3-4: vLLM Deployment
```bash
# 1. Deploy vLLM
helm repo add vllm https://vllm-project.github.io/vllm-helm-charts
helm install vllm vllm/vllm \
  --namespace vllm \
  --set model=mistralai/Mistral-7B-Instruct-v0.2 \
  --set gpu.count=1

# 2. Test LLM inference
curl http://vllm.vllm.svc.cluster.local:8000/generate \
  -d '{
    "prompt": "Explain machine learning in one sentence.",
    "max_tokens": 50
  }'
```

**Checklist:**
- [ ] GPU nodes provisioning correctly
- [ ] vLLM deployed with test model
- [ ] Inference working
- [ ] Token usage tracking configured
- [ ] Cost per request calculated
- [ ] Autoscaling tested

### Month 5: RAG Pipeline

#### Week 1-2: Vector Database (pgvector)
```bash
# 1. Deploy PostgreSQL with pgvector
helm install pgvector bitnami/postgresql \
  --set primary.initdb.scripts.init_pgvector\.sql="CREATE EXTENSION vector;"

# 2. Create embeddings table
psql << 'EOF'
CREATE TABLE embeddings (
  id SERIAL PRIMARY KEY,
  content TEXT,
  embedding vector(768),
  metadata JSONB
);
CREATE INDEX ON embeddings USING ivfflat (embedding vector_cosine_ops);
EOF
```

#### Week 3-4: RAG Application
```python
# rag_service.py
from sentence_transformers import SentenceTransformer
import psycopg2

class RAGService:
    def __init__(self):
        self.embedder = SentenceTransformer('all-MiniLM-L6-v2')
        self.db = psycopg2.connect(...)

    def ingest(self, documents):
        for doc in documents:
            embedding = self.embedder.encode(doc)
            self.db.execute(
                "INSERT INTO embeddings (content, embedding) VALUES (%s, %s)",
                (doc, embedding)
            )

    def query(self, question, top_k=5):
        q_embedding = self.embedder.encode(question)
        results = self.db.execute("""
            SELECT content, embedding <=> %s as distance
            FROM embeddings
            ORDER BY distance
            LIMIT %s
        """, (q_embedding, top_k))
        return results.fetchall()
```

**Checklist:**
- [ ] pgvector deployed
- [ ] Embedding service deployed
- [ ] Document ingestion working
- [ ] Similarity search working
- [ ] RAG pipeline integrated with vLLM
- [ ] Reranking implemented

### Month 6: Production Hardening

#### Week 1-2: LLM Observability
```bash
# Deploy LangSmith or Arize
# - Token usage tracking
# - Latency monitoring
# - Hallucination detection
# - Cost attribution
```

#### Week 3-4: Security & Compliance
```bash
# 1. Content filtering
# 2. PII detection/redaction
# 3. Rate limiting
# 4. API key management
# 5. Audit logging
```

**Phase 3 Complete!**
**Budget Check:** Should be ~$2,500-4,000/month

---

##  SUCCESS METRICS

### Phase 1
- [x] 99.9% uptime
- [x] All monitoring alerts firing
- [x] Costs within budget
- [x] State backup automated

### Phase 2
- [ ] Time to train model: < 4 hours
- [ ] Time to deploy model: < 15 minutes
- [ ] Model inference latency: P99 < 100ms
- [ ] Developer onboarding: < 1 day

### Phase 3
- [ ] LLM inference: P99 < 2 seconds
- [ ] Token cost: < $0.01 per request
- [ ] GPU utilization: > 60%
- [ ] Hallucination rate: < 5%

---

## CRITICAL CHECKPOINTS

### Before Phase 1 Deployment
- [ ] AWS credentials configured
- [ ] Email updated in terraform.tfvars
- [ ] S3 backend created
- [ ] Budget approved

### Before Phase 2 Deployment
- [ ] Phase 1 monitoring healthy
- [ ] Costs within expected range
- [ ] Team trained on Grafana/Prometheus
- [ ] Runbooks documented

### Before Phase 3 Deployment
- [ ] MLOps platform stable
- [ ] Models successfully served in Phase 2
- [ ] GPU budget approved ($1,000+/month)
- [ ] LLM use cases validated

---

**Next Steps:** Complete Phase 1 Week 1 Day 1-2 (S3 Backend Setup)
