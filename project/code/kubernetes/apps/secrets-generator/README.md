# Secrets Generator

[kubernetes-secret-generator](https://github.com/mittwald/kubernetes-secret-generator) generates random values directly in-cluster for `Secret`s whose value is just an internal agreed-upon token with no external source (service-to-service credentials, arbitrary shared keys). Nothing secure has to be sealed and committed to git for those, only a template is required.

## Usage

Annotate a `Secret` stub with `secret-generator.v1.mittwald.de/autogenerate` naming the key(s) to fill in and the controller populates them in place:

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: my-service-token
  namespace: secrets
  annotations:
    secret-generator.v1.mittwald.de/autogenerate: TOKEN
    secret-generator.v1.mittwald.de/encoding: base32
    secret-generator.v1.mittwald.de/length: "32"
type: Opaque
```

Multiple keys can be generated at once (comma-separated), e.g.
`AWS_ACCESS_KEY_ID,AWS_SECRET_ACCESS_KEY`.

## Rotate A Value

Patch the `Secret` with `secret-generator.v1.mittwald.de/regenerate: "yes"`. Don't commit this to git because it will just flap and cause the value to be constantly regenerated, just use ArgoCD or Headlamp to patch the manifest in-cluster or use the kubernetes commandline.

## More info

See [../secrets/README.md](../secrets/README.md) for how this fits into the cluster's overall secret management pattern (alongside Sealed Secrets and `kubernetes-reflector`), and where to actually add a new generated secret.
