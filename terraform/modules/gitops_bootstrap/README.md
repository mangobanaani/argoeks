# gitops_bootstrap

Installs the GitOps toolchain (Argo CD, optionally Flux) plus the supporting controllers (AWS Load Balancer Controller and ExternalDNS) into the hub cluster. The module focuses on cluster plumbing: it deploys the Helm charts, configures ingress, and wires IRSA roles that Terraform already created. After the Helm releases come up you still point Argo CD/Flux at your Git repos via Applications or Kustomizations.

## What it installs

- **Argo CD** Helm chart with ApplicationSet controller enabled, optional OIDC config, custom RBAC, and HTTPS ingress backed by ALB + ACM + WAF.
- **Flux v2** chart (optional) with Source/Kustomize/Helm/Notification controllers so teams that prefer Flux can reconcile repos alongside Argo.
- **AWS Load Balancer Controller** configured with the provided IRSA role to power internal ALB ingresses.
- **ExternalDNS** scoped to the provided Route53 private domain filters so ALB hostnames are published automatically.

## Prerequisites

- A kubeconfig/context configured for the management cluster and passed to the `kubernetes` and `helm` providers that call this module.
- IRSA roles for AWS Load Balancer Controller and ExternalDNS (modules `aws_lbc_irsa` and `external_dns_irsa` in this repo export the ARNs).
- ACM certificate and (optionally) WAF ACL ARNs when enabling TLS ingress.
- Git repos with the Argo CD bootstrap/AppSet manifests that you will apply after `terraform apply`.

## Usage

```hcl
module "gitops_bootstrap" {
  source                            = "../../modules/gitops_bootstrap"
  install_argocd                    = var.enable_argocd
  install_flux                      = var.enable_flux
  argocd_namespace                  = "argocd"
  flux_namespace                    = "flux-system"
  argocd_values                     = [file("../../../platform/argocd-hub/values.yaml")]
  argocd_oidc_enabled               = var.enable_argocd_sso
  argocd_server_service_type        = var.argocd_service_type
  argocd_server_service_annotations = var.argocd_service_annotations
  cluster_name                      = module.cluster_factory.cluster_names[0]
  aws_lbc_role_arn                  = module.aws_lbc_irsa.role_arn
  argocd_rbac_policy_csv            = <<-CSV
    g, platform:admin, role:admin
    g, platform:readonly, role:readonly
  CSV
  argocd_ingress_hosts         = [local.argocd_hostname]
  argocd_ingress_cert_arn      = module.argocd_cert[0].certificate_arn
  argocd_ingress_wafv2_acl_arn = module.argocd_waf[0].arn
  external_dns_domain_filters  = [var.private_domain]
  external_dns_role_arn        = lookup(module.external_dns_irsa.role_arns, module.cluster_factory.cluster_names[0], "")
  providers = {
    kubernetes = kubernetes.hub
    helm       = helm.hub
  }
}
```

## Inputs

The full list lives in `variables.tf`; highlights by category:

- **General toggles**: `install_argocd` (default `true`), `install_flux` (`false`), `install_aws_lbc` (`true`), `install_external_dns` (`true`).
- **Namespaces & Helm versions**: `argocd_namespace`, `flux_namespace`, `argocd_chart_version`, `flux_chart_version`, `aws_lbc_chart_version`, `external_dns_chart_version`.
- **Argo CD configuration**: `argocd_values` (extra Helm values), `argocd_admin_enabled`, `argocd_oidc_enabled` plus issuer/client inputs, `argocd_server_service_type`, `argocd_server_service_annotations`, `argocd_rbac_policy_csv`.
- **Ingress & TLS**: `argocd_ingress_enabled`, `argocd_ingress_hosts`, `argocd_ingress_cert_arn`, `argocd_ingress_wafv2_acl_arn`, `argocd_alb_name`, `alb_ssl_policy`.
- **AWS controller wiring**: `cluster_name`, `aws_lbc_role_arn`, `external_dns_role_arn`, `external_dns_domain_filters`, `external_dns_zone_id`.

## Outputs

None today (Argo CD/Flux components expose their own Kubernetes services). Add outputs here if you need to surface hostnames or IRSA details upstream.

## Operational notes

- After Terraform runs, apply `gitops/argocd/app-argocd-platform.yaml` (or your preferred bootstrap Application) so Argo CD starts reconciling cluster config.
- ExternalDNS is scoped to the provided domain filters; add multiple domains if you expose Argo CD or other ALBs in more than one private zone.
- Keep the Helm chart versions in `variables.tf` up to date; bumping them in one place propagates through every environment that consumes the module.
