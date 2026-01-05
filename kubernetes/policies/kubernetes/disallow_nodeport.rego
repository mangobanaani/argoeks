package kubepolicy

deny[msg] {
  input.kind.kind == "Service"
  input.spec.type == "NodePort"
  msg := sprintf("Service %s/%s uses NodePort", [input.metadata.namespace, input.metadata.name])
}

