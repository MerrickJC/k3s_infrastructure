# Centralized Secret Management

Every secret's source of truth lives in this app, deployed into a single `secrets` namespace, and gets fanned out to other namespace as needed. Three apps make this work:

- [secrets-sealed](../secrets-sealed/): the Sealed Secrets allows encrypted secrets to be committed to git and the controller decrypts `SealedSecret` ciphertext into a `Secret` which apps can use.
- [secrets-reflector](../secrets-reflector): [kubernetes-reflector](https://github.com/emberstack/kubernetes-reflector). It watches `Secret` objects carrying the `reflector.v1.k8s.emberstack.com/reflection-allowed` annotation and mirrors them into the namespaces listed in `reflector.v1.k8s.emberstack.com/reflection-allowed-namespaces`. It ensures mirrors are in sync whenever the source changes.
- [secrets-generator](../secrets-generator): [kubernetes-secret-generator](https://github.com/mittwald/kubernetes-secret-generator). It generates a random value directly in-cluster for secrets whose value is an arbitrary agreed-upon token with no external source, so nothing has to be sealed at all.

This app (`apps/secrets`) holds the manifests themselves as either a `SealedSecret` (externally-sourced value) or an annotated `Secret` stub (internally-generated value). Every secret lives in the `secrets` namespace and is reflected into other namespaces based on configuration. Every reflected copy keeps the same secret name and key(s).

## Which pattern a given secret uses

- Generated (annotated `Secret` stub): for values that are purely an internal agreed-upon token with no external source. See [example.yaml.example](./generated/example.yaml.example) for the manifest syntax. `secret-generator` populates `data.<key-name>` in place then `reflector` mirrors the populated `Secret` into the listed namespaces.

- Sealed (`SealedSecret`): for values that come from somewhere outside the cluster (an API key, an OAuth client secret issued by a third party, etc.). Seal once into the `secrets` namespace and add the same two reflector annotations to `spec.template.metadata.annotations` so the decrypted `Secret` gets reflected in the same way. See [sealed-secrets.md](../../../../../docs/kubernetes/sealed-secrets.md) for more information.

## Adding a new shared or generated secret

1. Decide: does the value come from outside the cluster (sealed) or is it just an agreed-upon token between services (generated)?
2. Add one manifest here, in the `secrets` namespace under either the `generated` or `sealed` folder, with `reflection-allowed-namespaces` set to every namespace that needs a copy.
3. Nothing needs to change in the consuming app(s) as long as the secret name and key match what they already expect.

## Rotation

`secret-generator` supports rotating a key via the `secret-generator.v1.mittwald.de/regenerate: "yes"` annotation. Once the key is rotated, the patched field will be removed. You could automate this with a CronJob if desired, however the downstream consumers (i.e. applications using the Secret) may not automatically pickup the new Secret depending on how they load secrets (e.g. if they only load secrets on container start-up then it won't hot reload), so beware that this may not behave as expected and you may have to manually restart some consumers to force them to fetch new Secret values.

If you need to rotate a secret manually due to a suspected compromise, you can patch the secret with `secret-generator.v1.mittwald.de/regenerate: "yes"` under the `metadata.annotations` field and the secret will regenerate with new values. A live manifest in-cluster is most easily edited using the ArgoCD UI to manually edit the manifest, or can be equally as easily edited via the Headlamp UI (both cases of course requiring the user to have appropriate authorization for the cluster). Same downstream consumer issue as in the above paragraph.
