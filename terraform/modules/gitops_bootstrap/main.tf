terraform {
  required_providers {
    kubernetes = {
      source = "hashicorp/kubernetes"
    }
    helm = {
      source = "hashicorp/helm"
    }
  }
}

resource "kubernetes_namespace_v1" "argocd" {
  count = var.install_argocd ? 1 : 0
  metadata { name = var.argocd_namespace }
}

resource "helm_release" "argocd" {
  count            = var.install_argocd ? 1 : 0
  name             = "argocd"
  namespace        = var.argocd_namespace
  repository       = "https://argoproj.github.io/argo-helm"
  chart            = "argo-cd"
  version          = var.argocd_chart_version
  create_namespace = false
  values = concat(var.argocd_values, [
    yamlencode({
      global = { image = {} }
      server = {
        service = { type = var.argocd_server_service_type, annotations = var.argocd_server_service_annotations
        }
        ingress = {
          enabled          = var.argocd_ingress_enabled
          ingressClassName = "alb"
          hosts            = var.argocd_ingress_hosts
          annotations = merge(
            {
              "alb.ingress.kubernetes.io/listen-ports" = "[{\"HTTPS\":443}]",
              "alb.ingress.kubernetes.io/scheme"       = "internal",
              "alb.ingress.kubernetes.io/target-type"  = "ip",
              "alb.ingress.kubernetes.io/ssl-redirect" = "443",
              "alb.ingress.kubernetes.io/ssl-policy"   = var.alb_ssl_policy
            },
            var.argocd_alb_name != "" ? { "alb.ingress.kubernetes.io/load-balancer-name" = var.argocd_alb_name } : {},
            var.argocd_ingress_cert_arn != "" ? { "alb.ingress.kubernetes.io/certificate-arn" = var.argocd_ingress_cert_arn } : {},
            var.argocd_ingress_wafv2_acl_arn != "" ? { "alb.ingress.kubernetes.io/wafv2-acl-arn" = var.argocd_ingress_wafv2_acl_arn } : {}
          )
        }
      }
      configs = {
        params = { "server.disable.auth" : false }
        cm = merge(
          {},
          var.argocd_oidc_enabled ? {
            "oidc.config" = <<-EOT
              name: SSO
              issuer: ${var.argocd_oidc_issuer}
              clientID: ${var.argocd_oidc_client_id}
              clientSecret: ${"oidc.clientSecret"}
              requestedIDTokenClaims:
                groups:
                  essential: true
              requestedScopes:
                - openid
                - profile
                - email
                - groups
            EOT
          } : {}
        )
        rbac = {
          "policy.csv"     = var.argocd_rbac_policy_csv
          "policy.default" = "role:readonly"
        }
        secret = {
          createSecret = true
          extra = merge({}, var.argocd_oidc_enabled ? {
            "oidc.clientSecret" = var.argocd_oidc_client_secret
          } : {})
        }
      }
      dex             = { enabled = false }
      configsSecret   = { create = true }
      controller      = {}
      repoServer      = {}
      applicationSet  = { enabled = true }
      notifications   = { enabled = false }
      server          = {}
      configsMap      = {}
      configsParams   = {}
      configsRbac     = {}
      configsSsh      = {}
      configsTlsCerts = {}
    })
  ])
  timeout    = 600
  wait       = true
  depends_on = [kubernetes_namespace_v1.argocd]
}

resource "kubernetes_namespace_v1" "flux" {
  count = var.install_flux ? 1 : 0
  metadata { name = var.flux_namespace }
}

resource "helm_release" "flux" {
  count            = var.install_flux ? 1 : 0
  name             = "flux2"
  namespace        = var.flux_namespace
  repository       = "https://fluxcd-community.github.io/helm-charts"
  chart            = "flux2"
  version          = var.flux_chart_version
  create_namespace = false
  values = concat([
    <<-YAML
    installCRDs: true
    components:
      sourceController: true
      kustomizeController: true
      helmController: true
      notificationController: true
    YAML
  ], var.flux_values)
  timeout    = 600
  wait       = true
  depends_on = [kubernetes_namespace_v1.flux]
}

resource "helm_release" "aws_load_balancer_controller" {
  count      = var.install_aws_lbc ? 1 : 0
  name       = "aws-load-balancer-controller"
  namespace  = "kube-system"
  repository = "https://aws.github.io/eks-charts"
  chart      = "aws-load-balancer-controller"
  version    = var.aws_lbc_chart_version
  wait       = true
  timeout    = 600
  values = [yamlencode({
    clusterName = var.cluster_name
    serviceAccount = {
      create      = true
      name        = "aws-load-balancer-controller"
      annotations = var.aws_lbc_role_arn != "" ? { "eks.amazonaws.com/role-arn" = var.aws_lbc_role_arn } : {}
    }
  })]
}

resource "helm_release" "external_dns" {
  count      = var.install_external_dns && length(var.external_dns_domain_filters) > 0 ? 1 : 0
  name       = "external-dns"
  namespace  = "kube-system"
  repository = "https://kubernetes-sigs.github.io/external-dns/"
  chart      = "external-dns"
  version    = var.external_dns_chart_version
  wait       = true
  timeout    = 600
  values = [yamlencode({
    provider      = "aws"
    policy        = "sync"
    txtOwnerId    = "external-dns-hub"
    domainFilters = var.external_dns_domain_filters
    serviceAccount = {
      create      = true
      name        = "external-dns"
      annotations = var.external_dns_role_arn != "" ? { "eks.amazonaws.com/role-arn" = var.external_dns_role_arn } : {}
    }
  })]
}
