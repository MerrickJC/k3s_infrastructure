# OIDC Authentication For kubectl / The Kubernetes API

## Why
By default, K3s only accepts client-certificate based auth for `kubectl`, which means the only way to grant someone cluster access is to hand them the admin kubeconfig (full `cluster-admin`, no per-person identity, no way to revoke a single person). This sets up Dex (already running in-cluster, see [dex/secrets/README.md](../../project/code/kubernetes/apps/dex/secrets/README.md)) as an OIDC provider for the Kubernetes API server itself, so every `kubectl` command requires logging in with your GitHub account, requiring membership in the `monashmotorsport` GitHub org.

**OIDC login only proves who you are (authentication). It does not grant any permissions on its own, that requires RBAC (authorization), which is configured separately.** See [project/code/kubernetes/apps/rbac-oidc/manifest.yaml](../../project/code/kubernetes/apps/rbac-oidc/manifest.yaml) for the two tiers granted here:

| Who | Access |
|---|---|
| Any `monashmotorsport` GitHub org member (i.e. anyone who can log in via Dex at all) | Read-only, cluster-wide, **excluding Secrets** (Kubernetes' built-in `view` role) |
| Members of the `monashmotorsport` GitHub team "Autonomous Systems" | `cluster-admin` |

The read-only tier is bound to Kubernetes' built-in `system:authenticated` group rather than a Dex org-membership group claim, since Dex is already configured to refuse to log anyone in who isn't a `monashmotorsport` org member (see `orgs:` in [dex/values.yaml](../../project/code/kubernetes/apps/dex/values.yaml)), so anyone who has logged in must be a member of monashmotorsport. The admin tier checks the group claim from Dex to see if the user is in autonomous-systems. 

**Dex uses kubernetes-backed storage** (`config.storage.type: kubernetes` in [dex/values.yaml](../../project/code/kubernetes/apps/dex/values.yaml)), not the default in-memory storage. Since Dex's signing key lives in that storage, with in-memory storage, every Dex pod restart silently regenerated the signing key and invalidated every outstanding token cluster-wide, breaking logins all at once with an `oidc: verify token: failed to verify signature` error. Kubernetes-backed storage persists the signing key as a CRD, so it survives pod restarts.

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

### Login
Then run:

```
kubectl oidc-login setup \
  --oidc-issuer-url=https://dex.merrickcampbell.au \
  --oidc-client-id=kubernetes \
  --oidc-extra-scope=groups,email,offline_access
```
> **If you do not have access to a web browser** on the device you are trying to log in on, you will need to also use the flags `--grant-type=authcode-keyboard --oidc-redirect-url=urn:ietf:wg:oauth:2.0:oob`. It will give you a URL to copy and paste into a browser, this will then give you a code that you can type to confirm the login.

This walks through a real login in your browser (GitHub → Dex → back to `kubectl`) and prints the exact commands you need to run to setup the user in your kubectl config file.

#### Troubleshooting
If you have issues like: 
```
E0812 00:39:33.761993  201838 memcache.go:265] "Unhandled Error" err="couldn't get current server API group list: the server has asked for the client to provide credentials"
error: You must be logged in to the server (the server has asked for the client to provide credentials)
```
then you can try removing your token using:
```
kubectl oidc-login clean
```
You will be asked to login again when you run the next command

### Configuration
After creating the user, you also need to configure the cluster and create a context which links the cluster to the user. Part of the configuration for the cluster involves using the certificates for the cluster's certificate authority to ensure that the cluster is who it says it is. MMS should attempt to maintain up-to-date certificates in [k3s-ca.crt](./k3s-ca.crt) so that developers don't need to go out of their way to find the certificates. You can, however, find the certificates by logging into the node that hosts the K3s server and running the following command:
```
sudo grep "certificate-authority-data" /etc/rancher/k3s/k3s.yaml | awk "{print \$2}" | base64 -d > k3s-ca.crt
```

Copy the `k3s-ca.crt` file onto your local machine (or use the [one provided](./k3s-ca.crt) if it is up-to-date) and run the following commands:
```
kubectl config set-cluster mms-cluster --server=<server-name-or-ip-and-port> --certificate-authority=k3s-ca.crt --embed-certs=true
kubectl config set-context mms-cluster-context --cluster=mms-cluster --user=oidc
kubectl config use-context mms-cluster-context
```
where the `server-name-or-ip-and-port` is the server's domain name or the ip address and port to connect to the server. You can optionally choose to rename "mms-cluster" and "mms-cluster-context" to something else, but it must be unique for the kubectl config file (see current configs by running `kubectl config view`). This must be unique, so if the team has multiple clusters then ensure to keep these clusters and contexts unique in your kubectl config.