module "tenant" {
  source          = "../irsa_s3"
  for_each        = { for t in var.tenants : t.namespace => t }
  name            = "kserve-${each.value.namespace}-irsa"
  namespace       = each.value.namespace
  service_account = each.value.service_account
  oidc_issuer_url = var.oidc_issuer_url
  bucket_arns     = [each.value.bucket_arn]
  kms_key_arns    = try([each.value.kms_arn], [])
  read_only       = try(each.value.read_only, true)
}

output "annotations" { value = { for k, v in module.tenant : k => v.annotations } }
