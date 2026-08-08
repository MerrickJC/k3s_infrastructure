# Certificates
Currently using cloudflare tunnels does not require TLS certificates, as cloudflare provides tls encryption for us. The certificates are added here so that they can be utilised in the future when needed and to prevent too much work-around having to re-add them during migration.

If you do not want the certificates to generate (due to not needing them because you already have TLS encryption). Then you can add a ```kustomization.yaml``` file to this folder with the following code to prevent the certificates generating:
```
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

namespace: ingress
```