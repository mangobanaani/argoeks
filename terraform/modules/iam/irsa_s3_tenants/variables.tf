variable "oidc_issuer_url" {
  type = string
}
variable "tenants" {
  description = "Per-namespace IRSA for KServe tenants"
  type = list(object({
    namespace       = string
    service_account = string
    bucket_arn      = string
    kms_arn         = optional(string)
    read_only       = optional(bool, true)
  }))
}
