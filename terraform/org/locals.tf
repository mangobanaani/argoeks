locals {
  default_ou_structure = {
    security          = "root"
    "shared-services" = "root"
    networking        = "shared-services"
    data              = "shared-services"
    workloads         = "root"
    training          = "workloads"
    serving           = "workloads"
    experiments       = "workloads"
    sandbox           = "workloads"
  }

  cloudtrail_bucket_name_resolved = var.cloudtrail_bucket_name != "" ? var.cloudtrail_bucket_name : (
    var.management_account_id != "" ? "${var.management_account_id}-org-trail-logs" : "org-trail-logs"
  )
}
