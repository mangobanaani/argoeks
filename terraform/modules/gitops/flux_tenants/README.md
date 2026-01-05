# flux_tenants

Creates multi-tenant landing zones for Flux Kustomizations. For each tenant string you pass in, the module provisions a namespace, a dedicated `kustomize-sa` ServiceAccount, and RBAC so Flux can reconcile that namespace without cluster-admin rights. It’s intended to pair with the Flux controllers that the `gitops_bootstrap` module deploys.

## What it configures

- Namespaces named `${namespace_prefix}${tenant}` (default prefix `tenant-`).
- `kustomize-sa` per namespace so each Flux `Kustomization` can impersonate only its tenant.
- A permissive `tenant-edit` Role + RoleBinding granting CRUD on namespaced resources. Adjust the role if your tenants need stricter policies.

## Usage

```hcl
module "flux_tenants" {
  source    = "../../modules/gitops/flux_tenants"
  enabled   = var.enable_flux
  tenants   = ["data-science", "ml-engineering"]
  providers = { kubernetes = kubernetes.hub }
}

# Sample Kustomization (Flux) referencing the service account this module created:
# spec:
#   serviceAccountName: kustomize-sa
#   targetNamespace: tenant-data-science
```

## Inputs

- `enabled` (bool, default `true`) – gate the entire module. When `false` no namespaces or accounts are created.
- `tenants` (list(string), required) – tenant identifiers. Valid Kubernetes namespace characters only.
- `namespace_prefix` (string, default `tenant-`) – prefix applied to each namespace so you can maintain consistent naming per environment.

See `variables.tf` for the definitive schema.

## Outputs

- `namespaces` – list of namespaces that were created (useful for wiring additional policies in calling modules).

## Operational notes

- Use Flux `Kustomization.spec.serviceAccountName = "kustomize-sa"` to ensure reconciliation happens with the scoped RoleBinding.
- Combine with Gatekeeper/PSA labels if tenants require additional policy boundaries; this module focuses only on RBAC scaffolding.
