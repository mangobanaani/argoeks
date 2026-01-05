# Autoscaling Configuration

## Overview

This directory contains autoscaling configurations using:
- **Horizontal Pod Autoscaler (HPA)**: Native Kubernetes autoscaling based on CPU/memory
- **KEDA**: Event-driven autoscaling based on external metrics (SQS, Prometheus, CloudWatch, etc.)

## Horizontal Pod Autoscaler (HPA)

### CPU-Based Autoscaling
Scale deployments based on CPU utilization:
```yaml
spec:
  minReplicas: 2
  maxReplicas: 10
  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 70
```

### Memory-Based Autoscaling
Scale deployments based on memory utilization:
```yaml
spec:
  metrics:
  - type: Resource
    resource:
      name: memory
      target:
        type: Utilization
        averageUtilization: 80
```

### Scaling Behavior
Control scale-up and scale-down behavior:
```yaml
spec:
  behavior:
    scaleDown:
      stabilizationWindowSeconds: 300  # Wait 5 minutes before scaling down
      policies:
      - type: Percent
        value: 50                       # Scale down by max 50% per minute
        periodSeconds: 60
    scaleUp:
      stabilizationWindowSeconds: 0    # Scale up immediately
      policies:
      - type: Percent
        value: 100                      # Double pods per 30 seconds
        periodSeconds: 30
```

## KEDA ScaledObjects

### AWS SQS Queue Scaling
```yaml
triggers:
- type: aws-sqs-queue
  metadata:
    queueURL: https://sqs.us-east-1.amazonaws.com/123456789012/my-queue
    queueLength: "5"                   # Target messages per replica
    awsRegion: us-east-1
    identityOwner: operator            # Use IRSA
```

### Prometheus Metrics Scaling
```yaml
triggers:
- type: prometheus
  metadata:
    serverAddress: http://prometheus-server.monitoring.svc:9090
    query: sum(rate(http_requests_total{job="api"}[2m]))
    threshold: "1000"                  # Target requests per second
```

### CloudWatch Metrics Scaling
```yaml
triggers:
- type: aws-cloudwatch
  metadata:
    namespace: AWS/ApplicationELB
    metricName: ActiveConnectionCount
    targetMetricValue: "1000"
    awsRegion: us-east-1
    identityOwner: operator            # Use IRSA
```

### Cron-Based Scaling
```yaml
triggers:
- type: cron
  metadata:
    timezone: America/New_York
    start: 0 8 * * 1-5                 # 8 AM weekdays
    end: 0 18 * * 1-5                  # 6 PM weekdays
    desiredReplicas: "10"
```

## Applying Configurations

### Create HPA
```bash
kubectl apply -f hpa-examples.yaml
```

### Create KEDA ScaledObjects
```bash
kubectl apply -f keda-scaledobjects.yaml
```

### Verify HPA Status
```bash
kubectl get hpa
kubectl describe hpa web-app-hpa
```

### Verify KEDA ScaledObjects
```bash
kubectl get scaledobjects
kubectl describe scaledobject sqs-queue-scaler
```

## Monitoring Autoscaling

### View HPA Events
```bash
kubectl get events --field-selector involvedObject.kind=HorizontalPodAutoscaler
```

### View KEDA Metrics
```bash
kubectl get --raw /apis/external.metrics.k8s.io/v1beta1
```

### KEDA Logs
```bash
kubectl logs -n keda deployment/keda-operator
kubectl logs -n keda deployment/keda-metrics-apiserver
```

## Best Practices

1. **Set appropriate min/max replicas**:
   - min >= 2 for high availability
   - max based on cost and capacity constraints

2. **Configure stabilization windows**:
   - Longer windows for scale-down to avoid flapping
   - Shorter windows for scale-up for responsiveness

3. **Use multiple metrics**:
   - Combine CPU, memory, and custom metrics
   - KEDA supports multiple triggers

4. **Test scaling behavior**:
   - Use load testing to verify thresholds
   - Monitor costs during high-traffic events

5. **Set resource requests/limits**:
   - HPA requires resource requests to be set
   - Ensure limits don't cause OOMKills during scale

## Examples by Use Case

### Web Application
- HPA with CPU target 70%
- Min replicas: 3, Max replicas: 20
- Fast scale-up, slow scale-down

### API Service
- KEDA with Prometheus metrics (requests/sec)
- HPA as fallback with CPU/memory
- Min replicas: 5, Max replicas: 50

### Queue Processor
- KEDA with SQS queue depth
- Min replicas: 1, Max replicas: 100
- Scale to zero when queue is empty

### Batch Processing
- KEDA with cron trigger
- Scale up during business hours
- Scale down to 1 replica overnight

### Stream Processing
- KEDA with Kafka/Kinesis lag
- Min replicas: 2, Max replicas: 30
- One replica per shard

## References

- [Kubernetes HPA Documentation](https://kubernetes.io/docs/tasks/run-application/horizontal-pod-autoscale/)
- [KEDA Documentation](https://keda.sh/)
- [KEDA Scalers](https://keda.sh/docs/latest/scalers/)
- [AWS IRSA for KEDA](https://keda.sh/docs/latest/authentication-providers/aws/)
