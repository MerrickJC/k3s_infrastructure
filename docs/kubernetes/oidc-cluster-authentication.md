# OIDC Authentication For kubectl / The Kubernetes API

## Why
By default, K3s only accepts client-certificate based auth for `kubectl`, which means the only way to grant someone cluster access is to hand them the admin kubeconfig (full `cluster-admin`, no per-person identity, no way to revoke a single person). This sets up Dex (already running in-cluster, see [dex/secrets/README.md](../../project/code/kubernetes/apps/dex/secrets/README.md)) as an OIDC provider for the Kubernetes API server itself, so every `kubectl` command requires logging in with your GitHub account, requiring membership in the `monashmotorsport` GitHub org.

**OIDC login only proves who you are (authentication). It does not grant any permissions on its own, that requires RBAC (authorization), which is configured separately.** See [project/code/kubernetes/apps/rbac-oidc/manifest.yaml](../../project/code/kubernetes/apps/rbac-oidc/manifest.yaml) for the two tiers granted here:

| Who | Access |
|---|---|
| Any `monashmotorsport` GitHub org member (i.e. anyone who can log in via Dex at all) | Read-only, cluster-wide, **excluding Secrets** (Kubernetes' built-in `view` role) |
| Members of the `monashmotorsport` GitHub team "Autonomous Systems" | `cluster-admin` |

The read-only tier is bound to Kubernetes' built-in `system:authenticated` group rather than a Dex org-membership group claim, since Dex is already configured to refuse to log anyone in who isn't a `monashmotorsport` org member (see `orgs:` in [dex/values.yaml](../../project/code/kubernetes/apps/dex/values.yaml)), so anyone who has logged in must be a member of monashmotorsport. The admin tier checks the group claim from Dex to see if the user is in autonomous-systems. 

## 1. Manual step: K3s API server flags (not stored in Git)
K3s server bootstrap lives outside this repository (see [migration-guide.md](../migration-guide.md)), so this step has to be applied by hand on every K3s **server** node (not agents).

Edit (or create) `/etc/rancher/k3s/config.yaml` on the node and add:

```yaml
kube-apiserver-arg:
  - "oidc-issuer-url=https://dex.merrickcampbell.au"
  - "oidc-client-id=kubernetes"
  - "oidc-username-claim=email"
  - "oidc-username-prefix=oidc:"
  - "oidc-groups-claim=groups"
  - "oidc-groups-prefix=oidc:"
```

Then restart K3s and confirm it is healthy **using your existing certificate-based admin kubeconfig**. This is typically stored in the ~/.kube/config file (do this before anything else to proves the change didn't break the API server):

```
sudo systemctl restart k3s
sudo systemctl status k3s
kubectl get nodes   # using the existing admin kubeconfig, NOT an OIDC login
```

No `oidc-ca-file` is required because Dex's issuer URL is served over public HTTPS via a Cloudflare Tunnel, so the node validates it against a normal public CA. This won't need to change after moving to a non-Cloudflare Tunnel setup, assuming that the ingress utilises LetsEncrypt to sign its certificates.

> **Keep your existing admin kubeconfig.** Adding OIDC auth is additive, so the client-certificate auth keeps working exactly as before. Never delete or rotate that credential as part of this setup; it's your break-glass access if Dex, GitHub, or the tunnel ever has an outage.

## 2. Client-side setup (per person)

Each person needs `kubectl`, `krew`, and the `oidc-login` plugin (see [commandline.md](./commandline.md) for installing those).

Then run:

```
kubectl oidc-login setup \
  --oidc-issuer-url=https://dex.merrickcampbell.au \
  --oidc-client-id=kubernetes \
  --oidc-extra-scope=groups,email,offline_access
```

This walks through a real login in your browser (GitHub → Dex → back to `kubectl`) and prints the exact `user:` block to paste into your `~/.kube/config`, e.g.:

```yaml
users:
  - name: oidc
    user:
      exec:
        apiVersion: client.authentication.k8s.io/v1beta1
        command: kubectl
        args:
          - oidc-login
          - get-token
          - --oidc-issuer-url=https://dex.merrickcampbell.au
          - --oidc-client-id=kubernetes
          - --oidc-extra-scope=groups,email,offline_access
```

Point a context's `user:` at this entry (alongside the cluster's API server address) and `kubectl` will open a browser login on first use, then cache/refresh the token.
