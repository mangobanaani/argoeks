package kubepolicy

deny[msg] {
  input.kind.kind == "Ingress"
  not input.spec.tls
  msg := sprintf("Ingress %s/%s missing TLS", [input.metadata.namespace, input.metadata.name])
}

