To add private repositories, create a Secret with label `argocd.argoproj.io/secret-type: repository` in `argocd` namespace.

Example (SSH key):

apiVersion: v1
kind: Secret
metadata:
  name: my-private-repo
  namespace: argocd
  labels:
    argocd.argoproj.io/secret-type: repository
type: Opaque
stringData:
  type: git
  url: git@github.com:org/private-repo.git
  sshPrivateKey: |
    -----BEGIN OPENSSH PRIVATE KEY-----
    ...
    -----END OPENSSH PRIVATE KEY-----

For token auth, provide `username` and `password` instead.

