# GitOps Bootstrap - ArgoCD and Flux deployment
module "gitops_bootstrap" {
  source                            = "../../modules/gitops_bootstrap"
  install_argocd                    = var.enable_argocd
  install_flux                      = var.enable_flux
  argocd_namespace                  = "argocd"
  flux_namespace                    = "flux-system"
  argocd_values                     = [file("../../../kubernetes/platform/argocd-hub/values.yaml")]
  argocd_admin_enabled              = false
  argocd_oidc_enabled               = var.enable_argocd_sso
  argocd_oidc_issuer                = var.argocd_sso_issuer
  argocd_oidc_client_id             = var.argocd_sso_client_id
  argocd_oidc_client_secret         = var.argocd_sso_client_secret
  argocd_server_service_type        = var.argocd_service_type
  argocd_server_service_annotations = var.argocd_service_annotations
  install_aws_lbc                   = false  # Already installed via helm_release below
  cluster_name                      = module.cluster_factory.cluster_names[0]
  aws_lbc_role_arn                  = module.aws_lbc_irsa.role_arn
  argocd_rbac_policy_csv            = <<-CSV
    g, platform:admin, role:admin
    g, platform:readonly, role:readonly
  CSV
  # HTTPS ingress with ACM + WAF
  argocd_ingress_enabled       = true
  argocd_ingress_hosts         = [local.argocd_hostname]
  argocd_ingress_cert_arn      = try(module.argocd_cert[0].certificate_arn, "")
  argocd_ingress_wafv2_acl_arn = try(module.argocd_waf[0].arn, "")
  install_external_dns         = true
  external_dns_domain_filters  = [var.private_domain]
  external_dns_role_arn        = lookup(module.external_dns_irsa.role_arns, module.cluster_factory.cluster_names[0], "")
  providers = {
    kubernetes = kubernetes.hub
    helm       = helm.hub
  }

  depends_on = [
    module.cluster_factory,
    module.cilium_hub,
    helm_release.aws_load_balancer_controller
  ]
}

# Network policies - Disabled for initial deployment, manage via ArgoCD in Phase 2
# module "network_policies" {
#   source    = "../../modules/kubernetes/network_policies"
#   enabled   = var.enable_network_policies
#   providers = { kubernetes = kubernetes.hub }
# }

# Gatekeeper - Phase 2: Manage via ArgoCD
# module "gatekeeper" {
#   source  = "../../modules/security/gatekeeper"
#   enabled = var.enable_gatekeeper
#   providers = {
#     kubernetes = kubernetes.hub
#     helm       = helm.hub
#   }
# }

# Flux tenants - Disabled for initial deployment, manage via ArgoCD in Phase 2
# module "flux_tenants" {
#   source    = "../../modules/gitops/flux_tenants"
#   enabled   = var.enable_flux
#   tenants   = var.tenants
#   providers = { kubernetes = kubernetes.hub }
# }

# Pod security labels - Disabled for initial deployment, manage via ArgoCD in Phase 2
# module "pod_security_labels" {
#   source    = "../../modules/security/pod_security_labels"
#   providers = { kubernetes = kubernetes.hub }
# }

# Private DNS for the environment, associated with all cluster VPCs
module "private_dns" {
  source  = "../../modules/networking/private_dns"
  enabled = var.enable_private_dns
  domain  = var.private_domain
  vpc_ids = values(module.cluster_factory.vpc_ids)
  region  = var.region
  tags    = { environment = "dev" }
}

# IRSA for ExternalDNS in every cluster, scoped to zone
module "external_dns_irsa" {
  source                   = "../../modules/dns/external_dns_irsa"
  zone_id                  = module.private_dns.zone_id
  cluster_names            = module.cluster_factory.cluster_names
  cluster_oidc_issuer_urls = module.cluster_factory.cluster_oidc_issuer_urls
  cluster_oidc_providers   = module.cluster_factory.cluster_oidc_providers
  region                   = var.region
  depends_on               = [module.cluster_factory]
}

module "eso_irsa" {
  source                   = "../../modules/iam/eso_irsa"
  cluster_names            = module.cluster_factory.cluster_names
  cluster_oidc_issuer_urls = module.cluster_factory.cluster_oidc_issuer_urls
  cluster_oidc_providers   = module.cluster_factory.cluster_oidc_providers
  depends_on               = [module.cluster_factory]
}

module "aws_lbc_irsa" {
  source          = "../../modules/iam/aws_lbc_irsa"
  name            = "dev-aws-lbc-irsa"
  oidc_issuer_url = data.aws_eks_cluster.hub.identity[0].oidc[0].issuer
}

resource "helm_release" "aws_load_balancer_controller" {
  provider        = helm.hub
  name            = "aws-load-balancer-controller"
  namespace       = "kube-system"
  repository      = "https://aws.github.io/eks-charts"
  chart           = "aws-load-balancer-controller"
  version         = "1.14.0"
  wait            = true
  timeout         = 600
  cleanup_on_fail = true

  values = [yamlencode({
    clusterName = module.cluster_factory.cluster_names[0]
    region      = var.region
    vpcId       = module.cluster_factory.vpc_ids[module.cluster_factory.cluster_names[0]]
    serviceAccount = {
      create = true
      name   = "aws-load-balancer-controller"
      annotations = {
        "eks.amazonaws.com/role-arn" = module.aws_lbc_irsa.role_arn
      }
    }
  })]

  depends_on = [module.cluster_factory, module.aws_lbc_irsa]
}

# ACM private cert for Argo CD (wildcard or host) and WAF ACL

# RBAC - Disabled for initial deployment, manage via ArgoCD in Phase 2
# module "rbac" {
#   source    = "../../modules/kubernetes/rbac"
#   enabled   = true
#   providers = { kubernetes = kubernetes.hub }
# }
