terraform {
  required_providers {
    kubernetes = {
      source = "hashicorp/kubernetes"
    }
    helm = {
      source = "hashicorp/helm"
    }
  }
}

resource "kubernetes_namespace_v1" "ns" {
  count = var.enabled ? 1 : 0
  metadata { name = var.namespace }
}

resource "helm_release" "gatekeeper" {
  count      = var.enabled ? 1 : 0
  name       = "gatekeeper"
  namespace  = var.namespace
  repository = "https://open-policy-agent.github.io/gatekeeper/charts"
  chart      = "gatekeeper"
  version    = var.gatekeeper_chart_version
  wait       = true
  timeout    = 600
  depends_on = [kubernetes_namespace_v1.ns]
}

# Baseline: require team/environment/cluster labels on Namespaces
# Note: Disabled for single-stage deployment
resource "kubernetes_manifest" "constraint_template" {
  count = 0
  manifest = {
    apiVersion = "templates.gatekeeper.sh/v1beta1"
    kind       = "ConstraintTemplate"
    metadata   = { name = "k8srequiredlabels" }
    spec = {
      crd = { spec = { names = { kind = "K8sRequiredLabels" } } }
      targets = [{
        target = "admission.k8s.gatekeeper.sh"
        rego   = <<-REGO
          package k8srequiredlabels
          violation[{"msg": msg, "details": {"missing_labels": missing}}] {
            provided := {label | input.review.object.metadata.labels[label]}
            required := {"team", "environment", "cluster"}
            missing := required - provided
            count(missing) > 0
            msg := sprintf("Missing labels: %v", [missing])
          }
        REGO
      }]
    }
  }
  depends_on = [helm_release.gatekeeper]
}

resource "kubernetes_manifest" "constraint" {
  count = 0  # Disabled for single-stage deployment
  manifest = {
    apiVersion = "constraints.gatekeeper.sh/v1beta1"
    kind       = "K8sRequiredLabels"
    metadata   = { name = "require-labels-all-clusters" }
    spec = {
      match = {
        kinds = [{ apiGroups = [""], kinds = ["Namespace"] }]
      }
      parameters = {
        labels = [{ key = "team" }, { key = "environment" }, { key = "cluster" }]
      }
    }
  }
  depends_on = [kubernetes_manifest.constraint_template]
}

## Additional security constraints for banks

# Allowed image registries (deny non-ECR by default)
resource "kubernetes_manifest" "ct_allowedrepos" {
  count = 0  # Disabled for single-stage deployment
  manifest = {
    apiVersion = "templates.gatekeeper.sh/v1beta1"
    kind       = "ConstraintTemplate"
    metadata   = { name = "k8sallowedrepos" }
    spec = {
      crd = {
        spec = {
          names = { kind = "K8sAllowedRepos" }
          validation = {
            openAPIV3Schema = {
              properties = {
                repos = {
                  type  = "array"
                  items = { type = "string" }
                }
              }
            }
          }
        }
      }
      targets = [{
        target = "admission.k8s.gatekeeper.sh"
        rego   = <<-REGO
        package k8sallowedrepos
        violation[{
          "msg": msg,
          "details": {"container": c.name, "image": c.image}
        }] {
          input.review.kind.kind == "Pod"
          c := input.review.object.spec.containers[_]
          not startswith(c.image, repo)
          repo := input.parameters.repos[_]
          msg := sprintf("container image not from allowed repos: %v", [c.image])
        }
        REGO
      }]
    }
  }
  depends_on = [helm_release.gatekeeper]
}

resource "kubernetes_manifest" "c_allowedrepos" {
  count = 0  # Disabled for single-stage deployment
  manifest = {
    apiVersion = "constraints.gatekeeper.sh/v1beta1"
    kind       = "K8sAllowedRepos"
    metadata   = { name = "allow-ecr-only" }
    spec = {
      match      = { kinds = [{ apiGroups = [""], kinds = ["Pod"] }] }
      parameters = { repos = ["*.dkr.ecr."] }
    }
  }
  depends_on = [kubernetes_manifest.ct_allowedrepos]
}

# Disallow :latest tag
resource "kubernetes_manifest" "ct_disallowlatest" {
  count = 0  # Disabled for single-stage deployment
  manifest = {
    apiVersion = "templates.gatekeeper.sh/v1beta1"
    kind       = "ConstraintTemplate"
    metadata   = { name = "k8sdisallowlatesttag" }
    spec = {
      crd = {
        spec = {
          names = { kind = "K8sDisallowLatestTag" }
        }
      }
      targets = [{
        target = "admission.k8s.gatekeeper.sh"
        rego   = <<-REGO
        package k8sdisallowlatesttag
        violation[{"msg": msg}] {
          input.review.kind.kind == "Pod"
          c := input.review.object.spec.containers[_]
          endswith(c.image, ":latest")
          msg := sprintf("disallowed tag :latest for image %v", [c.image])
        }
        REGO
      }]
    }
  }
  depends_on = [helm_release.gatekeeper]
}

resource "kubernetes_manifest" "c_disallowlatest" {
  count = 0  # Disabled for single-stage deployment
  manifest = {
    apiVersion = "constraints.gatekeeper.sh/v1beta1"
    kind       = "K8sDisallowLatestTag"
    metadata   = { name = "no-latest-tag" }
    spec       = { match = { kinds = [{ apiGroups = [""], kinds = ["Pod"] }] } }
  }
  depends_on = [kubernetes_manifest.ct_disallowlatest]
}
