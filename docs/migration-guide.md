# Migration Guide
This document aims to provide the key steps for migrating this Kubernetes setup from one cluster to another. While most of the setup is declarative and defined in Git using GitOps practices, there are some things that cannot be stored in Git or otherwise need to be setup externally for other reasons. This mainly is due to security, but also applies to ArgoCD (chicken egg problem).

Throughout this guide I will assume that you already have a cluster setup and that is currently working and that you are trying to lift and shift this into a different location. If some part of this is not true, then you may have mixed results following these steps.

<mark> THIS GUIDE IS NOT EXHAUSTIVE AND IS LIKELY MISSING STEPS </mark>

## ArgoCD Setup
ArgoCD is used to self-manage ArgoCD. To achieve this you just need to bootstrap the deployment once and then it will be able to self-manage from there. You can do this by running the following command from the root of the project repository:
```
kubectl apply -k ./project/code/kubernetes/argocd-management
```

## Sealed Secrets
In order to re-use the sealed secrets that were created for the previous cluster, you need to extract the encryption key that it uses and add this into the new cluster. You can find the steps for this [here](/docs/kubernetes/sealed-secrets.md#how-to-migrate-the-sealed-secret-tool).

If you cannot get the old encryption key, you will have to recreate all of the sealed secrets. You will have to find all the original values that were encrypted and [create new sealed secrets](/docs/kubernetes/sealed-secrets.md#how-to-create-one)

## OIDC Authentication For kubectl
The K3s API server's OIDC flags (which make it require a Dex login for `kubectl` access) are set on each server node's `/etc/rancher/k3s/config.yaml` and are not stored in Git for the same reason as the rest of the initial cluster setup. You will need to reapply them on the new cluster. See [here](/docs/kubernetes/oidc-cluster-authentication.md#1-manual-step-k3s-api-server-flags-not-stored-in-git) for the exact flags.

## Changing The Domain Name
### This Repo
You should be able to migrate domain by bulk-replacing every reference to `merrickcampbell.au` with your domain of choice. This will only update the references in this repository.

### External Dependencies
You will need to update any external dependencies for this cluster setup. At the moment, this is only:
- GitHub App
    - You will need to update the callback URLs for the GitHub App workflow. This should only require you to swap the `merrickcampbell.au` portion of the URLs and then it should continue working. The GitHub App is currently owned by the organisation monashmotorsport and can be managed by any organisation owner (as well as people with specific permissions) by going to [https://github.com/organizations/monashmotorsport/settings/apps](https://github.com/organizations/monashmotorsport/settings/apps) and selecting "BagAnTo".
- Cloudflare Tunnel
    - If continuing to use the Cloudflare Tunnel, you will need to update the tunnel's settings accordingly. See the [cloudflare tunnel setup information](./architecture/cloudflare-tunnel/configuration.md) for more guidance

## Changing The Git Repository
Updating the git repository can most likely be done by bulk-replacing the references to `git@github.com:MerrickJC/MerrickCampbell_MinorThesis_ROSDatabase.git` with the new repository instead. These references mostly appear in the [argocd-management folder](../project/code/kubernetes/argocd-management/).

ArgoCD will require a key to be able to read the new repository. The easiest way to add this is to use a sealed secret for the repository credentials. Create a file **locally** (DO NOT COMMIT IT!) called `repo-secret.yaml` and paste the following:
```yaml
# DO NOT COMMIT THIS FILE TO GIT
apiVersion: v1
kind: Secret
metadata:
  name: baganto-github-repository
  namespace: argocd
  labels:
    argocd.argoproj.io/secret-type: repository
stringData:
  url: ssh://git@github.com:<repository-details>.git
  sshPrivateKey: |
    -----BEGIN OPENSSH PRIVATE KEY-----
    <insert-ssh-deployment-key-here>
    -----END OPENSSH PRIVATE KEY-----
# DO NOT COMMIT THIS FILE TO GIT
```
where:
- `url` should be the ssh url of the git repository
- `sshPrivateKey` should be an SSH key for the repository. On GitHub I suggest using a read-only deployment key specific to the repository, as it will minimise risk and allow you to revoke the key easily in the future if needed

Then run:
```
kubeseal -f repo-secret.yaml -w repo-sealed-secret.yaml
```
Copy that file into the [argocd-management folder](../project/code/kubernetes/argocd-management/) and make sure that it is added to the [`kustomization.yaml`](../project/code/kubernetes/argocd-management/kustomization.yaml) as a resource so that it gets applied to the cluster. If there is already a file there for a git repository that you are no longer using, you can just overwrite that file.