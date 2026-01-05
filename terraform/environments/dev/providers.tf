terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "6.27.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "3.0.1"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "3.1.1"
    }
    random = {
      source  = "hashicorp/random"
      version = "3.7.2"
    }
  }

  backend "s3" {
    bucket         = "argoeks-terraform-state"
    key            = "dev/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "argoeks-terraform-locks"
    encrypt        = true
  }
}
provider "aws" {
  region  = var.region
  profile = var.aws_profile

  dynamic "assume_role" {
    for_each = var.workload_account_role_arn != "" ? [var.workload_account_role_arn] : []
    content {
      role_arn     = assume_role.value
      session_name = "terraform-${var.name_prefix}"
      external_id  = var.assume_role_external_id != "" ? var.assume_role_external_id : null
    }
  }
}

# Default Kubernetes provider (used by most modules)
provider "kubernetes" {
  host                   = try(values(module.cluster_factory.cluster_endpoints)[0], "")
  cluster_ca_certificate = try(base64decode(values(module.cluster_factory.cluster_certificate_authorities)[0]), "")
  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    args = [
      "eks",
      "get-token",
      "--cluster-name",
      try(module.cluster_factory.hub_cluster_name, "dev-mlops-cluster-01"),
      "--region",
      var.region
    ]
  }
}

# Hub cluster alias (used by specific modules)
provider "kubernetes" {
  alias                  = "hub"
  host                   = try(values(module.cluster_factory.cluster_endpoints)[0], "")
  cluster_ca_certificate = try(base64decode(values(module.cluster_factory.cluster_certificate_authorities)[0]), "")
  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    args = [
      "eks",
      "get-token",
      "--cluster-name",
      try(module.cluster_factory.hub_cluster_name, "dev-mlops-cluster-01"),
      "--region",
      var.region
    ]
  }
}

# Default Helm provider (used by most modules)
provider "helm" {
  kubernetes {
    host                   = try(values(module.cluster_factory.cluster_endpoints)[0], "")
    cluster_ca_certificate = try(base64decode(values(module.cluster_factory.cluster_certificate_authorities)[0]), "")
    exec {
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = "aws"
      args = [
        "eks",
        "get-token",
        "--cluster-name",
        try(module.cluster_factory.hub_cluster_name, "dev-mlops-cluster-01"),
        "--region",
        var.region
      ]
    }
  }
}

# Hub cluster alias (used by specific modules)
provider "helm" {
  alias = "hub"
  kubernetes {
    host                   = try(values(module.cluster_factory.cluster_endpoints)[0], "")
    cluster_ca_certificate = try(base64decode(values(module.cluster_factory.cluster_certificate_authorities)[0]), "")
    exec {
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = "aws"
      args = [
        "eks",
        "get-token",
        "--cluster-name",
        try(module.cluster_factory.hub_cluster_name, "dev-mlops-cluster-01"),
        "--region",
        var.region
      ]
    }
  }
}

provider "aws" {
  alias  = "billing"
  region = "us-east-1"

  dynamic "assume_role" {
    for_each = var.management_role_arn != "" ? [var.management_role_arn] : []
    content {
      role_arn     = assume_role.value
      session_name = "terraform-billing-${var.name_prefix}"
    }
  }
}
