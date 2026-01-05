terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws        = { source = "hashicorp/aws", version = "~> 5.95" } # EKS module v20.x requires < 6.0.0
    kubernetes = { source = "hashicorp/kubernetes", version = "~> 2.38" }
    helm       = { source = "hashicorp/helm", version = "~> 3.1" }
    random     = { source = "hashicorp/random", version = "~> 3.7" }
  }
}
