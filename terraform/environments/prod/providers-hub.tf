locals {
  hub_primary   = module.cluster_factory_primary.cluster_names[0]
  hub_secondary = module.cluster_factory_secondary.cluster_names[0]
}

data "aws_eks_cluster" "hub_primary" {
  provider = aws.primary
  name     = local.hub_primary
}

data "aws_eks_cluster_auth" "hub_primary" {
  provider = aws.primary
  name     = local.hub_primary
}

data "aws_eks_cluster" "hub_secondary" {
  provider = aws.secondary
  name     = local.hub_secondary
}

data "aws_eks_cluster_auth" "hub_secondary" {
  provider = aws.secondary
  name     = local.hub_secondary
}

provider "kubernetes" {
  alias                  = "hub_primary"
  host                   = data.aws_eks_cluster.hub_primary.endpoint
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.hub_primary.certificate_authority[0].data)
  token                  = data.aws_eks_cluster_auth.hub_primary.token
}

provider "helm" {
  alias = "hub_primary"
  kubernetes {
    host                   = data.aws_eks_cluster.hub_primary.endpoint
    cluster_ca_certificate = base64decode(data.aws_eks_cluster.hub_primary.certificate_authority[0].data)
    token                  = data.aws_eks_cluster_auth.hub_primary.token
  }
}

provider "kubernetes" {
  alias                  = "hub_secondary"
  host                   = data.aws_eks_cluster.hub_secondary.endpoint
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.hub_secondary.certificate_authority[0].data)
  token                  = data.aws_eks_cluster_auth.hub_secondary.token
}

provider "helm" {
  alias = "hub_secondary"
  kubernetes {
    host                   = data.aws_eks_cluster.hub_secondary.endpoint
    cluster_ca_certificate = base64decode(data.aws_eks_cluster.hub_secondary.certificate_authority[0].data)
    token                  = data.aws_eks_cluster_auth.hub_secondary.token
  }
}
