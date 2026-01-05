# Optional Modules Guide

This guide documents the 7 optional modules kept in the codebase as "ready-to-use" patterns. These modules are not currently active but provide valuable capabilities when needed.

## Quick Reference

| Module | Use Case | Cost/Month | When to Enable |
|--------|----------|------------|----------------|
| [vpc_lattice_core](#vpc-lattice) | Multi-VPC/region service mesh | ~$50-100 | Multi-region prod, cross-env services |
| [elasticache_memcached](#memcached) | High-throughput caching | ~$12 | Simple key-value caching at scale |
| [ingress_nginx](#nginx-ingress) | K8s-native ingress | ~$100 | Advanced routing, WebSocket support |
| [aurora_global](#aurora-global) | Multi-region database | ~2x Aurora | Global ML model serving |
| [greengrass_v2](#greengrass) | Edge ML deployment | Free + IoT | Edge inference, offline ML |
| [ecr_scanning](#ecr-scanning) | Container security | Free-$50 | Compliance, vuln scanning |
| [ml/mlflow](#mlflow) | IaC MLflow deployment | Varies | Repeatable MLflow infra |

## How to Use

1. **Check** if the module solves your use case (see sections below)
2. **Copy** example from `/terraform/environments/dev/optional-modules.tf.example`
3. **Uncomment** and configure for your environment
4. **Rename** file to `optional-modules.tf`
5. **Run** `terraform init && terraform plan` to verify
6. **Apply** when ready

---

## VPC Lattice

**Module**: `terraform/modules/ingress/vpc_lattice_core`

### What It Does
Creates AWS VPC Lattice service network for cross-VPC and cross-region service communication. Think of it as a managed service mesh for connecting services across network boundaries.

### When to Enable

 **Use when**:
- You have multi-region production (primary + secondary)
- You need cross-environment service access (dev   qa   prod)
- You want to share services across AWS accounts
- You have hybrid architectures (EKS + Lambda + EC2)
- You need tenant service isolation with controlled sharing

 **Don't use when**:
- Single VPC, single cluster (use Cilium only)
- Cost is primary concern and networking is simple
- All services are pod-to-pod (use Cilium cluster mesh)

### Integration with Cilium

VPC Lattice and Cilium are **complementary**:
- **Cilium cluster mesh**: Pod-to-pod within/across K8s clusters (fast, eBPF)
- **VPC Lattice**: Service-level routing across VPCs/regions (AWS-managed)

```
Layer 1: Cilium eBPF   Pod-to-pod (same cluster)
Layer 2: Cilium cluster mesh   Pod-to-pod (multi-cluster)
Layer 3: VPC Lattice   Service-to-service (multi-VPC/region)
```

### MLOps Use Cases

**Multi-Region Model Serving**:
```
Primary region (us-east-1):
  - Training clusters
  - MLflow tracking server
  - Model registry

Secondary region (us-west-2):
  - Inference endpoints (vLLM, Triton)
  - Read-only model access

VPC Lattice: Secondary inference   Primary MLflow (metadata, experiments)
```

**Cross-Environment Model Promotion**:
```
Dev   QA   Prod pipeline
All environments access shared MLflow in dev
VPC Lattice provides secure, IAM-controlled access
```

### Cost
- Service network: Free
- Per service: ~$18/month
- Data transfer: $0.01/GB (in-region), $0.02/GB (cross-region)
- **Typical setup**: $50-100/month for 3-5 services

### Example Configuration
See `/terraform/environments/dev/optional-modules.tf.example` lines 8-27

---

## Memcached

**Module**: `terraform/modules/cache/elasticache_memcached`

### What It Does
Creates AWS ElastiCache Memcached cluster for distributed, high-throughput caching.

### When to Enable

 **Use when**:
- Need simple key-value caching (no persistence required)
- Multi-threaded workloads (Memcached handles threads better than Redis)
- Higher throughput more important than features
- Cache invalidation is handled by application

 **Don't use when**:
- Need persistence, pub/sub, or complex data structures (use Redis)
- Already using Redis successfully
- Cost is primary concern (Redis is default)

### Redis vs Memcached

| Feature | Redis | Memcached |
|---------|-------|-----------|
| Persistence |  |  |
| Pub/Sub |  |  |
| Data structures |  Lists, sets, sorted sets |  Key-value only |
| Multi-threading |  Single-threaded |  Multi-threaded |
| Throughput | Good | Excellent |
| Memory efficiency | Good | Better |

### MLOps Use Cases

**Feature Store Caching**:
```
Feast online store   Memcached
High-throughput feature lookups during inference
Simple key-value (feature_id   feature_vector)
```

**Model Metadata Cache**:
```
MLflow model metadata   Memcached
Reduce database load for frequent model lookups
No persistence needed (backed by database)
```

### Cost
- cache.t3.micro (2 nodes): ~$12/month
- cache.r6g.large (2 nodes): ~$200/month

### Example Configuration
See `/terraform/environments/dev/optional-modules.tf.example` lines 38-57

---

## NGINX Ingress

**Module**: `terraform/modules/addons/ingress_nginx`

### What It Does
Deploys NGINX Ingress Controller as alternative to AWS Load Balancer Controller.

### When to Enable

 **Use when**:
- Need advanced routing features (regex, rewrites, custom headers)
- Better WebSocket support required
- Want K8s-native ingress (portable across clouds)
- Need custom NGINX configurations
- gRPC streaming with advanced routing

 **Don't use when**:
- AWS ALB features are sufficient (default)
- Cost is primary concern (AWS LBC is cheaper)
- Simple HTTP/HTTPS routing only

### AWS LBC vs NGINX

| Feature | AWS Load Balancer Controller | NGINX Ingress |
|---------|------------------------------|---------------|
| Cloud portability |  AWS-only |  Multi-cloud |
| Cost | Lower (~$18/month ALB) | Higher (~$100/month + compute) |
| WebSocket | Basic | Advanced |
| gRPC | Basic | Advanced |
| Custom routing | Limited | Extensive |
| SSL termination | ALB | In-cluster or ALB |
| Rate limiting | Basic | Advanced |

### MLOps Use Cases

**JupyterHub with WebSockets**:
```
NGINX handles Jupyter kernel WebSocket connections
Better connection stability than ALB
```

**Multi-Tenant Routing**:
```
tenant-a.mlflow.internal   Namespace A
tenant-b.mlflow.internal   Namespace B
Advanced path rewrites and auth
```

### Cost
- NGINX pods: ~$50/month compute (2 replicas)
- NLB (if used): ~$18/month
- **Total**: ~$100/month vs ~$18/month for AWS LBC

### Example Configuration
See `/terraform/environments/dev/optional-modules.tf.example` lines 72-102

---

## Aurora Global

**Module**: `terraform/modules/db/aurora_global`

### What It Does
Creates multi-region Aurora Global Database with <1s replication latency.

### When to Enable

 **Use when**:
- Multi-region production with data requirements
- Global ML model serving from single database
- Disaster recovery with fast RTO/RPO
- Read replicas needed in multiple regions

 **Don't use when**:
- Single region is sufficient
- Cost is primary concern (2x Aurora cost)
- Can tolerate higher latency cross-region reads

### Use Cases

**Global Model Registry**:
```
Primary (us-east-1): MLflow writes
Secondary (eu-west-1): MLflow reads for European inference
Secondary (ap-southeast-1): MLflow reads for APAC inference
<1s replication lag
```

**Multi-Region Feature Store**:
```
Primary: Feast writes
Secondary regions: Feast reads for local inference
Low-latency access worldwide
```

### Cost
- Primary cluster: Standard Aurora cost
- Secondary clusters: ~Same as primary per region
- **Typical**: 2x-3x Aurora cost for 2-3 regions

### Example Configuration
See `/terraform/environments/dev/optional-modules.tf.example` lines 116-137

---

## Greengrass

**Module**: `terraform/modules/edge/greengrass_v2`

### What It Does
Deploys AWS IoT Greengrass v2 for edge ML inference on devices.

### When to Enable

 **Use when**:
- Edge ML deployment (factories, retail stores, vehicles)
- Offline inference required (intermittent connectivity)
- Local processing for latency/bandwidth savings
- IoT device fleet management

 **Don't use when**:
- All inference is cloud-based
- No edge devices in architecture
- Real-time cloud connectivity guaranteed

### MLOps Use Cases

**Factory Quality Inspection**:
```
Edge devices: Industrial cameras
Model: vLLM vision model (quantized)
Processing: Local inference on defects
Sync: Periodic model updates from cloud
```

**Retail Shelf Analytics**:
```
Edge: Store cameras + Greengrass
Model: Object detection (low-latency)
Cloud: Aggregate analytics
```

### Cost
- Greengrass software: Free
- AWS IoT Core: $1.20 per million messages
- Edge compute: Your hardware
- **Typical**: $10-50/month for device fleet

### Example Configuration
See `/terraform/environments/dev/optional-modules.tf.example` lines 151-174

---

## ECR Scanning

**Module**: `terraform/modules/container/ecr_scanning`

### What It Does
Configures automated vulnerability scanning for ECR container images.

### When to Enable

 **Use when**:
- Compliance requirements (SOC2, PCI-DSS, HIPAA)
- Security posture monitoring needed
- Want automated CVE detection
- Need reporting on image vulnerabilities

 **Don't use when**:
- Using external scanning tools (Snyk, Aqua, etc.)
- No compliance requirements
- Cost is critical concern

### Scanning Types

| Type | Cost | Features |
|------|------|----------|
| Basic | Free | Common vulnerabilities (CVEs) |
| Enhanced | $0.09/image | AWS Inspector, OS + app vulns |

### MLOps Use Cases

**Model Container Security**:
```
Scan: vllm-inference, triton-server images
Detect: Vulnerable PyTorch, CUDA libs
Alert: Critical CVEs to security team
Policy: Block high-severity deployments
```

**Compliance Reporting**:
```
Weekly scans of all ML containers
Track vulnerability trends
Compliance dashboard for audits
```

### Cost
- Basic scanning: Free
- Enhanced scanning: ~$0.09 per image scan
- **Typical**: $20-50/month for 10 repos, daily scans

### Example Configuration
See `/terraform/environments/dev/optional-modules.tf.example` lines 188-217

---

## MLflow

**Module**: `terraform/modules/ml/mlflow`

### What It Does
Deploys MLflow tracking server via Terraform (alternative to Helm/ArgoCD).

### When to Enable

 **Use when**:
- Want infrastructure-as-code MLflow deployment
- Need version-controlled MLflow configuration
- Terraform is your primary deployment tool
- Want repeatable MLflow across environments

 **Don't use when**:
- Already deploying MLflow via Helm/ArgoCD
- GitOps is your deployment pattern
- ml_workloads_irsa module sufficient (IRSA only)

### Current Recommendation

**For IRSA only**: Use `ml_workloads_irsa` module (already configured)

**For full deployment**: This module OR Helm chart via ArgoCD

### Use Cases

**Terraform-First Teams**:
```
All infrastructure in Terraform
MLflow deployed same way as databases
Single state, single workflow
```

**Multi-Environment Consistency**:
```
Dev, QA, Prod: Identical MLflow configs
Promoted via Terraform workspaces/environments
```

### Cost
Varies by configuration (compute + storage)

### Example Configuration
See `/terraform/environments/dev/optional-modules.tf.example` lines 231-273

---

## Summary

**Current state**: All 7 modules exist and are maintained, but not active in any environment

**Ready to use**: Uncomment examples in `optional-modules.tf.example` and configure

**Deprecation**: Only `iam/irsa_mlflow` should be removed (replaced by `irsa_ml_workloads`)

**Philosophy**: Keep valuable work accessible. Make modules discoverable with clear documentation.

## Related Documentation

- `/terraform/environments/dev/optional-modules.tf.example` - Commented configuration examples
- `/docs/stack-optimization.md` - Optimization strategy and module analysis
- `/terraform/modules/ingress/vpc_lattice_core/README.md` - VPC Lattice detailed guide
- `/docs/CILIUM_ENABLEMENT.md` - Cilium + VPC Lattice integration
