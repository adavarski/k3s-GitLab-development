apiVersion: cert-manager.io/v1alpha2
kind: Certificate
metadata:
  name: gitlab-davar
  namespace: gitlab
spec:
  secretName: gitlab-davar-tls
  issuerRef:
    name: selfsigned-issuer
    kind: ClusterIssuer
  commonName: gitlab.dev.davar.com
  dnsNames:
    - gitlab.dev.davar.com
    - reg.gitlab.dev.davar.com
