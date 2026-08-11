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