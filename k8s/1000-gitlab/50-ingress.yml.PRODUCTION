apiVersion: extensions/v1beta1
kind: Ingress
metadata:
  name: gitlab
  namespace: gitlab
  labels:
    app: gitlab
  annotations:
    traefik.ingress.kubernetes.io/redirect-entry-point: https
spec:
  rules:
    - host: gitlab.dev.davar.com
      http:
        paths:
          - backend:
              serviceName: gitlab
              servicePort: 80
            path: /
    - host: reg.gitlab.dev.davar.com
      http:
        paths:
          - backend:
              serviceName: gitlab
              servicePort: 5050
            path: /
  tls:
    - hosts:
        - reg.gitlab.dev.davar.com
        - gitlab.dev.davar.com
      secretName: gitlab-davar-tls
