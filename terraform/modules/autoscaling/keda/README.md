# KEDA Event-Driven Autoscaling Module

Deploys KEDA (Kubernetes Event-Driven Autoscaling) for workload autoscaling based on external metrics and event sources.

## Overview

This module installs KEDA on EKS clusters with:
- Event-driven autoscaling for workloads
- IRSA for AWS service access (SQS, CloudWatch, DynamoDB, Kinesis)
- High availability with multiple replicas and Pod Disruption Budget
- Prometheus metrics integration
- Support for 50+ scalers (SQS, Kafka, Prometheus, Cron, etc.)

## Features

- IRSA-based authentication for AWS services (no static credentials)
- Built-in scalers for AWS services: SQS, CloudWatch, DynamoDB Streams, Kinesis
- Custom metrics from Prometheus
- Cron-based scaling for predictable workloads
- External metrics from any HTTP endpoint
- High availability with 2+ replicas and PDB
- Prometheus ServiceMonitor for metrics collection

## Usage

### Basic Configuration

```hcl
module "keda" {
  source = "../../modules/autoscaling/keda"

  cluster_name       = "prod-cluster-01"
  namespace          = "keda"
  create_namespace   = true

  enable_irsa        = true
  oidc_provider_arn  = module.eks.oidc_provider_arn
  oidc_issuer_url    = module.eks.cluster_oidc_issuer_url

  replicas           = 2
  enable_pdb         = true
  pdb_min_available  = 1

  enable_prometheus_servicemonitor = true

  keda_version = "2.16.0"

  tags = {
    cluster     = "prod-cluster-01"
    environment = "prod"
    purpose     = "autoscaling"
  }

  providers = {
    kubernetes = kubernetes.hub
    helm       = helm.hub
  }
}
```

### Custom Resource Limits

```hcl
module "keda" {
  source = "../../modules/autoscaling/keda"

  cluster_name = "prod-cluster-01"

  operator_resources = {
    limits_cpu      = "2000m"
    limits_memory   = "2000Mi"
    requests_cpu    = "200m"
    requests_memory = "200Mi"
  }

  metrics_server_resources = {
    limits_cpu      = "1000m"
    limits_memory   = "1000Mi"
    requests_cpu    = "100m"
    requests_memory = "100Mi"
  }

  enable_irsa       = true
  oidc_provider_arn = module.eks.oidc_provider_arn
  oidc_issuer_url   = module.eks.cluster_oidc_issuer_url

  tags = {
    environment = "prod"
  }
}
```

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|----------|
| install | Whether to install KEDA | bool | true | no |
| cluster_name | Name of the EKS cluster | string | - | yes |
| namespace | Kubernetes namespace for KEDA | string | "keda" | no |
| create_namespace | Create the namespace for KEDA | bool | true | no |
| keda_version | KEDA Helm chart version | string | "2.16.0" | no |
| enable_irsa | Enable IAM Roles for Service Accounts | bool | true | no |
| oidc_provider_arn | ARN of the OIDC provider for IRSA | string | "" | no |
| oidc_issuer_url | OIDC issuer URL without https:// | string | "" | no |
| create_service_account | Create Kubernetes service account for KEDA | bool | true | no |
| service_account_name | Name of the service account | string | "keda-operator" | no |
| operator_resources | Resource limits for KEDA operator | object | See below | no |
| metrics_server_resources | Resource limits for metrics server | object | See below | no |
| replicas | Number of KEDA operator replicas | number | 2 | no |
| enable_pdb | Enable Pod Disruption Budget | bool | true | no |
| pdb_min_available | Minimum available pods for PDB | number | 1 | no |
| enable_prometheus_servicemonitor | Enable Prometheus ServiceMonitor | bool | true | no |
| tags | Tags to apply to AWS resources | map(string) | {} | no |

### Default Operator Resources

```hcl
{
  limits_cpu      = "1000m"
  limits_memory   = "1000Mi"
  requests_cpu    = "100m"
  requests_memory = "100Mi"
}
```

### Default Metrics Server Resources

```hcl
{
  limits_cpu      = "1000m"
  limits_memory   = "1000Mi"
  requests_cpu    = "100m"
  requests_memory = "100Mi"
}
```

## Outputs

| Name | Description |
|------|-------------|
| namespace | Kubernetes namespace where KEDA is installed |
| iam_role_arn | IAM role ARN for KEDA service account |
| service_account_name | Name of the KEDA service account |
| helm_release_name | Name of the KEDA Helm release |
| helm_release_version | Version of the KEDA Helm release |

## Dependencies

### Terraform Providers
- hashicorp/kubernetes >= 2.20
- hashicorp/helm >= 2.10
- hashicorp/aws >= 5.0 (if enable_irsa = true)

### External Dependencies
- EKS cluster with OIDC provider (if enable_irsa = true)
- Cilium CNI or other CNI must be operational
- Prometheus Operator CRDs (if enable_prometheus_servicemonitor = true)

### Module Dependencies
```
cluster_factory → cilium → keda
```

## Resources Created

### AWS Resources (if enable_irsa = true)
- IAM role for KEDA IRSA
- IAM policy (SQS, CloudWatch, DynamoDB, Kinesis permissions)

### Kubernetes Resources
- Namespace (keda)
- KEDA Helm release
  - keda-operator deployment
  - keda-metrics-apiserver deployment
  - ServiceAccount with IRSA annotation
  - ServiceMonitor (if enabled)
  - PodDisruptionBudget (if enabled)

## IAM Permissions

KEDA IRSA role has permissions for:
- **SQS**: GetQueueAttributes, GetQueueUrl
- **CloudWatch**: GetMetricData, GetMetricStatistics, ListMetrics
- **DynamoDB**: DescribeTable, DescribeStream
- **Kinesis**: DescribeStream, GetRecords, GetShardIterator

## ScaledObject Examples

### SQS Queue Scaler

```yaml
apiVersion: keda.sh/v1alpha1
kind: ScaledObject
metadata:
  name: sqs-scaler
  namespace: default
spec:
  scaleTargetRef:
    name: queue-processor
  minReplicaCount: 1
  maxReplicaCount: 20
  triggers:
  - type: aws-sqs-queue
    metadata:
      queueURL: https://sqs.us-east-1.amazonaws.com/123456789012/my-queue
      queueLength: "5"
      awsRegion: us-east-1
      identityOwner: operator  # Use IRSA
```

### CloudWatch Metrics Scaler

```yaml
apiVersion: keda.sh/v1alpha1
kind: ScaledObject
metadata:
  name: cloudwatch-scaler
spec:
  scaleTargetRef:
    name: api-service
  minReplicaCount: 2
  maxReplicaCount: 10
  triggers:
  - type: aws-cloudwatch
    metadata:
      namespace: AWS/ApplicationELB
      dimensionName: LoadBalancer
      dimensionValue: app/my-lb/50dc6c495c0c9188
      metricName: ActiveConnectionCount
      targetMetricValue: "1000"
      awsRegion: us-east-1
      identityOwner: operator
```

### Prometheus Metrics Scaler

```yaml
apiVersion: keda.sh/v1alpha1
kind: ScaledObject
metadata:
  name: prometheus-scaler
spec:
  scaleTargetRef:
    name: worker
  minReplicaCount: 2
  maxReplicaCount: 30
  triggers:
  - type: prometheus
    metadata:
      serverAddress: http://prometheus-server.monitoring:9090
      metricName: http_requests_total
      query: sum(rate(http_requests_total{job="api"}[2m]))
      threshold: "1000"
```

### Cron Scaler (Scheduled Scaling)

```yaml
apiVersion: keda.sh/v1alpha1
kind: ScaledObject
metadata:
  name: cron-scaler
spec:
  scaleTargetRef:
    name: batch-processor
  minReplicaCount: 1
  maxReplicaCount: 1
  triggers:
  - type: cron
    metadata:
      timezone: America/New_York
      start: 0 8 * * 1-5      # 8 AM weekdays
      end: 0 18 * * 1-5        # 6 PM weekdays
      desiredReplicas: "10"
```

## Supported Scalers

KEDA supports 50+ scalers including:

### AWS Services
- SQS Queue
- CloudWatch Metrics
- DynamoDB Streams
- Kinesis Stream
- S3 (via CloudWatch Events)

### Messaging
- Kafka
- RabbitMQ
- Azure Service Bus
- Google Pub/Sub
- NATS

### Databases
- PostgreSQL
- MySQL
- MongoDB
- Redis

### Metrics
- Prometheus
- Datadog
- New Relic
- Graphite

### Other
- HTTP (webhook)
- Cron (scheduled)
- CPU/Memory (native Kubernetes metrics)

See [KEDA Scalers](https://keda.sh/docs/scalers/) for full list.

## High Availability

KEDA is deployed with HA by default:
- 2 replicas of keda-operator
- PodDisruptionBudget ensures minimum 1 replica available
- Metrics server for external metrics API
- Leader election for operator instances

## Monitoring

When `enable_prometheus_servicemonitor = true`, KEDA exports metrics:
- `keda_scaler_errors_total` - Scaler errors count
- `keda_scaler_metrics_value` - Current metric value from scaler
- `keda_scaled_object_errors` - ScaledObject errors
- `keda_resource_totals` - Total ScaledObjects/ScaledJobs

Query Prometheus:
```promql
keda_scaler_metrics_value{scaledObject="sqs-scaler"}
```

## ScaledObject vs HPA

### Use KEDA ScaledObject when:
- Scaling based on external metrics (SQS, Kafka, etc.)
- Event-driven workloads with sporadic traffic
- Need to scale to zero replicas
- Complex scaling logic (multiple triggers)

### Use HPA when:
- Scaling based on CPU/memory only
- Workloads must maintain minimum replicas > 0
- Simple scaling requirements

## Operations

### List ScaledObjects

```bash
kubectl get scaledobjects -A
```

### Describe ScaledObject

```bash
kubectl describe scaledobject sqs-scaler -n default
```

### Check KEDA Operator Logs

```bash
kubectl logs -n keda deployment/keda-operator -f
```

### Check Metrics Server

```bash
kubectl logs -n keda deployment/keda-metrics-apiserver -f
```

### Pause Scaling

```bash
kubectl annotate scaledobject sqs-scaler \
  autoscaling.keda.sh/paused-replicas=0
```

### Resume Scaling

```bash
kubectl annotate scaledobject sqs-scaler \
  autoscaling.keda.sh/paused-replicas-
```

## Security Considerations

- Uses IRSA (no long-lived credentials in cluster)
- ServiceAccount annotated with IAM role ARN
- IAM policy follows least privilege (read-only access to metrics)
- Pod security context: non-root user (UID 1000)
- Namespace has baseline Pod Security Standard

## Troubleshooting

### ScaledObject Not Scaling

Check KEDA operator logs:
```bash
kubectl logs -n keda deployment/keda-operator
```

Check ScaledObject status:
```bash
kubectl describe scaledobject <name>
```

### IRSA Authentication Failures

Verify ServiceAccount annotation:
```bash
kubectl get sa keda-operator -n keda -o yaml | grep role-arn
```

Test AWS credentials:
```bash
kubectl run test -it --rm --image=amazon/aws-cli \
  --serviceaccount=keda-operator -n keda \
  -- sts get-caller-identity
```

### Metrics Not Available

Check metrics server:
```bash
kubectl get apiservice v1beta1.external.metrics.k8s.io
kubectl logs -n keda deployment/keda-metrics-apiserver
```

## Cost Optimization

KEDA enables significant cost savings:
- Scale to zero during idle periods
- Scale based on actual workload (not just CPU/memory)
- Optimize resource utilization with precise scaling
- Reduce over-provisioning with event-driven scaling

Example: SQS queue scaler can reduce costs by 70%+ for batch workloads.

## Related Documentation

- [Autoscaling Examples](../../../../kubernetes/platform/autoscaling/keda-scaledobjects.yaml)
- [HPA vs KEDA Comparison](../../../../kubernetes/platform/autoscaling/README.md)
- [KEDA Documentation](https://keda.sh/docs/)
- [KEDA Scalers Reference](https://keda.sh/docs/scalers/)
