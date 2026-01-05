locals {
  hub_name = module.cluster_factory.cluster_names[0]
}

data "aws_eks_cluster" "hub" {
  name = local.hub_name
}

data "aws_eks_cluster_auth" "hub" {
  name = local.hub_name
}

provider "kubernetes" {
  alias                  = "hub"
  host                   = data.aws_eks_cluster.hub.endpoint
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.hub.certificate_authority[0].data)
  token                  = data.aws_eks_cluster_auth.hub.token
}

provider "helm" {
  alias = "hub"
  kubernetes {
    host                   = data.aws_eks_cluster.hub.endpoint
    cluster_ca_certificate = base64decode(data.aws_eks_cluster.hub.certificate_authority[0].data)
    token                  = data.aws_eks_cluster_auth.hub.token
  }
}

