# MLOps Network Policies Module

Enhanced network policies designed for ML workloads. Supports both standard Kubernetes NetworkPolicy and Cilium NetworkPolicy with L3-L7 capabilities.

## Features

- **Dual Mode**: Works with any CNI (standard mode) or Cilium (enhanced mode)
- **Default Deny**: Applies zero-trust networking to specified namespaces
- **ML-Aware**: Special policies for training and inference workloads
- **FQDN Filtering**: Allow egress to specific AWS services (S3, ECR, etc.) when using Cilium
- **Distributed Training**: Supports inter-pod communication for frameworks like PyTorch DDP
- **Platform Security**: Restricts platform namespaces to HTTPS-only egress

## Usage

### Basic (Standard Kubernetes NetworkPolicy)

```hcl
module "network_policies" {
  source = "../../modules/kubernetes/network_policies_mlops"

  enabled     = true
  cilium_mode = false

  platform_namespaces = ["argocd", "monitoring", "flux-system"]
  tenant_namespaces   = ["team-alpha", "team-beta"]

  providers = {
    kubernetes = kubernetes.hub
  }
}
```

### Enhanced (Cilium NetworkPolicy)

```hcl
module "network_policies" {
  source = "../../modules/kubernetes/network_policies_mlops"

  enabled     = true
  cilium_mode = true

  enable_ml_policies = true

  ml_training_namespaces  = ["kubeflow", "training"]
  ml_inference_namespaces = ["inference", "serving"]

  # Allow inference pods to access these services
  inference_allowed_services = [
    {
      k8sService = {
        serviceName = "postgres"
        namespace   = "database"
      }
    },
    {
      k8sService = {
        serviceName = "feast"
        namespace   = "feature-store"
      }
    }
  ]

  providers = {
    kubernetes = kubernetes.hub
  }
}
```

## Policy Types

### 1. Default Deny (All Namespaces)

**Standard Mode**: Creates 3 policies per namespace:
- `default-deny-ingress`
- `default-deny-egress`
- `allow-dns`

**Cilium Mode**: Creates 1 policy per namespace:
- `default-deny-with-dns` (includes DNS allow)

### 2. ML Training Policies (Cilium Only)

Applied to pods with label `workload-type: training`

**Allowed Egress**:
- Other training pods (distributed training)
- S3, ECR, STS, CloudWatch (AWS ML services)
- Kubernetes API (for job orchestration)

**Allowed Ingress**:
- Monitoring namespace (Prometheus scraping)
- Other training pods (all-reduce, NCCL)

### 3. ML Inference Policies (Cilium Only)

Applied to pods with label `workload-type: inference`

**Allowed Egress**:
- S3 (model artifacts)
- Configured services (databases, feature stores)

**Allowed Ingress**:
- Ingress controllers (ALB Controller, NGINX)
- Monitoring namespace

### 4. Platform HTTPS-Only (Cilium Only)

Applied to platform namespaces (argocd, monitoring, etc.)

**Allowed Egress**:
- HTTPS (port 443) only
- DNS

## Labels Required

### For ML Training Workloads

```yaml
apiVersion: v1
kind: Pod
metadata:
  labels:
    workload-type: training
spec:
  # Your training container
```

### For ML Inference Workloads

```yaml
apiVersion: v1
kind: Pod
metadata:
  labels:
    workload-type: inference
spec:
  # Your inference container
```

## Cilium vs Standard Mode

| Feature | Standard Mode | Cilium Mode |
|---------|---------------|-------------|
| **CNI Requirement** | Any CNI | Cilium only |
| **L3/L4 Policies** | Yes | Yes |
| **L7 (HTTP) Policies** | No | Yes |
| **FQDN Filtering** | No | Yes |
| **Service-based Rules** | Limited | Full |
| **Inter-namespace** | Yes | Yes |
| **Performance** | Good | Better (eBPF) |
| **Observability** | Basic | Advanced (Hubble) |

## Migration Path

1. **Start with Standard Mode** on existing clusters
2. **Test with Cilium Mode** in sandbox/dev
3. **Validate** training and inference workloads work correctly
4. **Roll out** to QA, then Production

## Inputs

| Name | Description | Type | Default |
|------|-------------|------|---------|
| enabled | Enable network policies | bool | true |
| cilium_mode | Use Cilium NetworkPolicy | bool | false |
| platform_namespaces | Platform namespaces to secure | list(string) | [argocd, monitoring, ...] |
| tenant_namespaces | Tenant namespaces to secure | list(string) | [] |
| enable_ml_policies | Enable ML-specific policies | bool | true |
| ml_training_namespaces | Training workload namespaces | list(string) | [kubeflow, training, mlops] |
| ml_inference_namespaces | Inference workload namespaces | list(string) | [inference, serving, mlops] |
| inference_allowed_services | Services inference can access | list(object) | [postgres, redis] |

## Outputs

| Name | Description |
|------|-------------|
| secured_namespaces | List of namespaces with policies |
| cilium_mode_enabled | Whether Cilium mode is active |
| ml_policies_enabled | Whether ML policies are enabled |
| policy_count | Number of policies created |

## Examples

### Example 1: Distributed PyTorch Training

With Cilium policies, your PyTorch DDP training job automatically gets:
- All-reduce communication between pods
- S3 access for datasets
- ECR access for pulling containers
- Blocked from external internet
- Blocked from other namespaces

### Example 2: Triton Inference Service

With Cilium policies, your Triton inference pods get:
- Ingress from ALB
- S3 access for models
- Database access (if configured)
- Prometheus scraping
- Blocked from training namespace
- Blocked from arbitrary egress

### Example 3: Multi-Tenant Isolation

```hcl
module "network_policies" {
  source = "../../modules/kubernetes/network_policies_mlops"

  enabled = true
  cilium_mode = true

  tenant_namespaces = [
    "team-alpha",
    "team-beta",
    "team-gamma"
  ]

  # Each team is isolated by default
  # Add explicit policies for cross-team communication
}
```

## Troubleshooting

### Pods Can't Reach S3

**Symptom**: Training pods timeout connecting to S3

**Solution**: Ensure pods have label `workload-type: training` and namespace is in `ml_training_namespaces`

```bash
# Check labels
kubectl get pods -n training --show-labels

# Verify policy
kubectl get ciliumnetworkpolicy -n training
kubectl describe ciliumnetworkpolicy ml-training-egress -n training
```

### Distributed Training Communication Blocked

**Symptom**: PyTorch DDP training fails with "connection refused"

**Solution**: Verify pods have matching labels and policy allows inter-pod communication

```bash
# Check with Hubble (if Cilium enabled)
hubble observe --from-label workload-type=training --to-label workload-type=training

# Should show FORWARDED, not DROPPED
```

### Inference Can't Reach Database

**Symptom**: 500 errors from inference API, database connection timeouts

**Solution**: Add database service to `inference_allowed_services`

```hcl
inference_allowed_services = [
  {
    k8sService = {
      serviceName = "postgres"
      namespace   = "database"
    }
  }
]
```

## Best Practices

1. **Start permissive, then restrict**: Begin with `policy_enforcement_mode = "default"`, monitor with Hubble, then tighten
2. **Use labels consistently**: Standardize on `workload-type` label across all ML workloads
3. **Test in sandbox first**: Always validate policies in non-prod before applying to production
4. **Monitor with Hubble**: Use Hubble UI to visualize allowed/denied flows
5. **Document exceptions**: If you must allow additional egress, document why in the policy

## Related Modules

- `networking/cilium` - Cilium CNI installation
- `security/pod_security_labels` - Pod Security Standards
- `security/gatekeeper` - OPA policy enforcement
- `kubernetes/rbac` - Kubernetes RBAC configuration
