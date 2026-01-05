# Providers for Kubernetes/Helm resources
# Cilium CNI Installation Module
# BYOCNI: Full Cilium CNI replacement (no chaining) for maximum performance

locals {
  cilium_version = var.cilium_version

  # Extract hostname from cluster endpoint (remove https://)
  cluster_api_host = replace(var.cluster_endpoint, "https://", "")

  # Cilium configuration optimized for MLOps workloads
  cilium_values = {
    # Full CNI mode - Cilium is the sole CNI provider (no chaining)
    cni = {
      chainingMode = "none"
      exclusive    = true
    }

    # Kube-proxy replacement - required for full CNI mode
    k8sServiceHost = local.cluster_api_host
    k8sServicePort = var.cluster_endpoint_port

    # eBPF host routing for maximum performance (replaces deprecated tunnel parameter)
    routingMode = "native"

    # Masquerade traffic leaving the node (required for full CNI mode)
    egressMasqueradeInterfaces = "eth0"

    # AWS ENI mode for IP address management
    eni = {
      enabled = true
      # Use AWS VPC IPAM but Cilium datapath
      awsReleaseExcessIPs         = true
      updateEC2AdapterLimitViaAPI = true
    }

    # Enable Hubble for network observability
    hubble = {
      enabled = true
      relay = {
        enabled  = true
        replicas = var.hubble_relay_replicas
      }
      ui = {
        enabled  = var.hubble_ui_enabled
        replicas = 1
        ingress = {
          enabled     = var.hubble_ingress_enabled
          annotations = var.hubble_ingress_annotations
          hosts       = [var.hubble_hostname]
        }
      }
      metrics = {
        enabled = var.hubble_metrics_enabled ? [
          "dns:query;ignoreAAAA",
          "drop",
          "tcp",
          "flow",
          "icmp",
          "http"
        ] : []
        serviceMonitor = {
          enabled = var.enable_prometheus_servicemonitor
          labels = {
            prometheus = "kube-prometheus-stack"
          }
          trustCRDsExist = true
        }
        # ML-relevant metrics
        enabledList = [
          "dns:query;ignoreAAAA",
          "drop",
          "tcp",
          "flow",
          "icmp",
          "http"
        ]
      }
    }

    # Prometheus metrics integration
    prometheus = {
      enabled = var.enable_prometheus_servicemonitor
      serviceMonitor = {
        enabled = var.enable_prometheus_servicemonitor
        labels = {
          prometheus = "kube-prometheus-stack"
        }
        trustCRDsExist = true
      }
    }

    # Operator configuration
    operator = {
      replicas = 2
      prometheus = {
        enabled = var.enable_prometheus_servicemonitor
        serviceMonitor = {
          enabled        = var.enable_prometheus_servicemonitor
          trustCRDsExist = true
        }
      }
    }

    # IPv4 native routing
    ipam = {
      mode = "eni"
    }

    # Enable bandwidth manager for fair queueing (critical for multi-tenant ML)
    bandwidthManager = {
      enabled = var.bandwidth_manager_enabled
      bbr     = false # Disabled: AL2 kernel < 5.18 doesn't support BBR
    }

    # BGP for hybrid/bare-metal GPU nodes
    bgp = {
      enabled = var.bgp_enabled
      announce = {
        loadbalancerIP = var.bgp_announce_lb
        podCIDR        = var.bgp_announce_pod_cidr
      }
    }

    # Cluster mesh for multi-cluster (1-50 clusters)
    clustermesh = {
      useAPIServer = var.clustermesh_enabled
      apiserver = {
        replicas = 2
        service = {
          type = "LoadBalancer"
          annotations = {
            "service.beta.kubernetes.io/aws-load-balancer-internal" = "true"
            "service.beta.kubernetes.io/aws-load-balancer-type"     = "nlb"
          }
        }
      }
      config = {
        enabled  = true
        clusters = var.clustermesh_clusters
      }
    }

    # Security - NetworkPolicy enforcement
    policyEnforcementMode = var.policy_enforcement_mode

    # Enable identity-aware policies (for IRSA integration)
    identityAllocationMode = "crd"

    dns = {
      enableSearchPath = true
      baseDomain       = "cluster.local"
      teamsAutopath    = true
      coredns          = { enabled = true }
    }

    # Kube-proxy replacement (better performance)
    kubeProxyReplacement = var.kube_proxy_replacement

    # Enable AWS security groups for pods
    aws = {
      securityGroupsForPods = {
        enabled = var.security_groups_for_pods
      }
    }

    # Encryption (optional - impacts performance)
    encryption = {
      enabled        = var.enable_encryption
      type           = var.enable_encryption ? "wireguard" : ""
      nodeEncryption = var.enable_encryption
    }

    # Resource limits
    resources = var.cilium_resources

    # Pod disruption budget
    podDisruptionBudget = {
      enabled      = true
      minAvailable = 1
    }
  }
}

# Create namespace
resource "kubernetes_namespace_v1" "cilium" {
  count = var.install && var.namespace != "kube-system" ? 1 : 0

  metadata {
    name = var.namespace
    labels = {
      "pod-security.kubernetes.io/enforce" = "privileged"
      "pod-security.kubernetes.io/audit"   = "privileged"
      "pod-security.kubernetes.io/warn"    = "privileged"
    }
  }
}

# Install Cilium via Helm
resource "helm_release" "cilium" {
  count = var.install ? 1 : 0

  name       = "cilium"
  repository = "https://helm.cilium.io/"
  chart      = "cilium"
  version    = local.cilium_version
  namespace  = var.namespace

  timeout         = 600
  wait            = true   # Wait for Cilium to be ready before node group creation
  wait_for_jobs   = true
  cleanup_on_fail = true

  values = [
    yamlencode(local.cilium_values)
  ]

  depends_on = [kubernetes_namespace_v1.cilium]
}

# Cluster mesh secrets (if enabled)
resource "kubernetes_secret" "clustermesh" {
  count = var.clustermesh_enabled && length(var.clustermesh_remote_clusters) > 0 ? 1 : 0

  metadata {
    name      = "cilium-clustermesh"
    namespace = var.namespace
  }

  data = {
    for cluster_name, cluster_config in var.clustermesh_remote_clusters :
    "${cluster_name}" => jsonencode({
      name      = cluster_name
      id        = cluster_config.cluster_id
      addresses = cluster_config.addresses
      tls = {
        ca   = cluster_config.ca_cert
        cert = cluster_config.client_cert
        key  = cluster_config.client_key
      }
    })
  }

  depends_on = [helm_release.cilium]
}

# ServiceMonitor for Prometheus integration
# Note: Disabled for single-stage deployment - enable manually after first apply if needed
resource "kubernetes_manifest" "cilium_servicemonitor" {
  count = 0

  manifest = {
    apiVersion = "monitoring.coreos.com/v1"
    kind       = "ServiceMonitor"
    metadata = {
      name      = "cilium-agent"
      namespace = var.namespace
      labels = {
        app = "cilium"
      }
    }
    spec = {
      selector = {
        matchLabels = {
          "k8s-app" = "cilium"
        }
      }
      endpoints = [
        {
          port     = "prometheus"
          interval = "30s"
        }
      ]
    }
  }

  depends_on = [helm_release.cilium]
}

# Hubble ServiceMonitor
# Note: Disabled for single-stage deployment - enable manually after first apply if needed
resource "kubernetes_manifest" "hubble_servicemonitor" {
  count = 0

  manifest = {
    apiVersion = "monitoring.coreos.com/v1"
    kind       = "ServiceMonitor"
    metadata = {
      name      = "hubble"
      namespace = var.namespace
      labels = {
        app = "hubble"
      }
    }
    spec = {
      selector = {
        matchLabels = {
          "k8s-app" = "hubble"
        }
      }
      endpoints = [
        {
          port     = "metrics"
          interval = "30s"
        }
      ]
    }
  }

  depends_on = [helm_release.cilium]
}

# Network Policy for GPU workloads (example)
resource "kubernetes_manifest" "gpu_network_policy" {
  count = var.create_sample_policies ? 1 : 0

  manifest = {
    apiVersion = "cilium.io/v2"
    kind       = "CiliumNetworkPolicy"
    metadata = {
      name      = "gpu-training-policy"
      namespace = "default"
    }
    spec = {
      description = "Allow GPU training pods to communicate with each other and S3"
      endpointSelector = {
        matchLabels = {
          "workload-type" = "gpu-training"
        }
      }
      egress = [
        {
          toEndpoints = [
            {
              matchLabels = {
                "workload-type" = "gpu-training"
              }
            }
          ]
        },
        {
          toFQDNs = [
            { matchPattern = "*.s3.*.amazonaws.com" },
            { matchPattern = "*.ecr.*.amazonaws.com" }
          ]
          toPorts = [
            {
              ports = [
                { port = "443", protocol = "TCP" }
              ]
            }
          ]
        }
      ]
      ingress = [
        {
          fromEndpoints = [
            {
              matchLabels = {
                "workload-type" = "gpu-training"
              }
            }
          ]
        }
      ]
    }
  }

  depends_on = [helm_release.cilium]
}

# BYOCNI: No need to remove aws-node daemonset - it's never installed
