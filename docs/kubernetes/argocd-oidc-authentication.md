# OIDC Authentication For ArgoCD

## Why
This wires ArgoCD's login into the same Dex instance already used in the cluster, so people log in with GitHub, gated on `monashmotorsport` org membership, with the same two-tier access model:

| Who | Access |
|---|---|
| Any `monashmotorsport` org member | ArgoCD's built-in `role:readonly` |
| Members of the `monashmotorsport` GitHub team "Autonomous Systems" | ArgoCD's built-in `role:admin` |

See [project/code/kubernetes/argocd-management/argocd-rbac-cm-patch.yaml](../../project/code/kubernetes/argocd-management/argocd-rbac-cm-patch.yaml) for the policy.

## `oidc.config`, not `dex.config`
ArgoCD ships its own bundled `argocd-dex-server`, which is normally used to front an upstream identity provider itself (`dex.config`). Since this project already runs a full, standalone Dex instance as the shared IdP for everything else, ArgoCD is instead pointed straight at it as a native OIDC issuer. This can be seen under `oidc.config` in `argocd-cm` (see [argocd-cm-patch.yaml](../../project/code/kubernetes/argocd-management/argocd-cm-patch.yaml)). This avoids running two overlapping Dex instances. `argocd-dex-server` still gets deployed (it's part of the upstream install manifest ArgoCD is built from) but is simply unused.

Because ArgoCD is bootstrapped by referencing the upstream `install.yaml` directly (see `project/code/kubernetes/argocd-management/kustomization.yaml`), the `argocd-cm` / `argocd-rbac-cm` ConfigMaps can't be edited in place, so they're overridden with Kustomize `patches` in that same `kustomization.yaml`, merging in just the OIDC/RBAC keys.

## Setting up the client secret
ArgoCD requires sealing secrets like any other Dex client
```bash
kubectl create secret generic argocd-dex-client-secret --from-literal=ARGOCD_DEX_CLIENT_SECRET="<random-value>" -n dex --dry-run=client -o yaml | kubeseal --format yaml > project/code/kubernetes/apps/dex/secrets/argocd-dex.yaml

kubectl create secret generic argocd-dex-client-secret --from-literal=ARGOCD_DEX_CLIENT_SECRET="<same-random-value>" -n argocd --dry-run=client -o yaml | kubeseal --format yaml > project/code/kubernetes/apps/dex/secrets/argocd-client.yaml
```

**Configuration Specific To ArgoCD:** the Secret created in the `argocd` namespace must carry the label
`app.kubernetes.io/part-of: argocd`, or ArgoCD's secret informer won't watch it and the
`$argocd-dex-client-secret:ARGOCD_DEX_CLIENT_SECRET` reference in `argocd-cm-patch.yaml` will silently
fail to resolve. Add the label to the `template.metadata.labels` of the sealed secret before you commit it to git:

```yaml
  template:
    metadata:
      name: argocd-dex-client-secret
      namespace: argocd
      labels:
        app.kubernetes.io/part-of: argocd
```
