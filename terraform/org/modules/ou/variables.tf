variable "ou_structure" {
  description = "Map of OU name => parent key (use \"root\" for root-level). Parents must exist in the same map."
  type        = map(string)
  default = {
    security         = "root"
    "shared-services" = "root"
    networking       = "shared-services"
    data             = "shared-services"
    workloads        = "root"
    training         = "workloads"
    serving          = "workloads"
    experiments      = "workloads"
    sandbox          = "workloads"
  }

  validation {
    condition = alltrue([
      for name, parent in var.ou_structure :
      parent == "root" || contains(keys(var.ou_structure), parent)
    ])
    error_message = "Each parent must be \"root\" or the name of another OU in the map."
  }
}
