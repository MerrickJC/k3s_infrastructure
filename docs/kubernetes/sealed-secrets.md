# Sealed Secrets
## What Is It?
We want as much of the cloud configuration as possible to be defined using Infrastructure as Code (IaC) so that we can employ a GitOps deployment model. We utilise ArgoCD to support this. One of the challenges with defining everything using IaC in Git is that you don't want to commit plaintext representations of anything sensitive (e.g. API keys, security tokens, etc). This can be solved by encrypting the sensitive content and storing it in Git in this encrypted form. The challenge is that you still need a way to decrypt this data in your cluster. To do this securely, we utilise the [sealed secrets tool](https://github.com/bitnami/sealed-secrets) provided by bitnami. The tool consists of an encryption key which is auto-generated and stored in the cluster

## Warnings
Sealed secrets are not permanently secret! They are decrypted and stored within the cluster in a way that is retrievable by anyone with access to the cluster via the kubectl commandline. This means you shouldn't put anything in there that you genuinely do not want found out. Do not put your own personal passwords in there and expect them to be safe!

## How To Create One?
Assume that you have some value that you are trying to store in a secret in Kubernetes. Please note that a sealed secret can only be used in the namespace it was created. Attempting to use the sealed secret in a different namespace will not be permitted unless an appropriate ServiceAccount, Role, and RoleBinding exists (this should be avoided). 
```
kubectl create secret generic <secret-name> --from-literal=<secret-key>=<secret-value> -n <namespace> --dry-run=client -o yaml | kubeseal --format yaml > sealed-secret.yaml
```

## How To Migrate The Sealed Secret Tool?
### In The Old Cluster
Run the following command while connected to the old cluster:
```
kubectl get secret -n kube-system -l sealedsecrets.bitnami.com/sealed-secrets-key -o yaml >main.key
```
**THIS STORES THE PRIVATE ENCRYPTION KEY TO A FILE LOCALLY ON YOUR DEVICE. DO NOT LEAK THIS. DO NOT COMMIT THIS TO GIT. DO NOT SEND THIS VIA MESSAGE.** This encryption key can decrypt any secret stored as a sealed secret in the Git repository, so you should not retain it on your device for longer than you need to.

### In The New Cluster
Deploy the sealed secret tool into the new cluster. You can do that by setting up ArgoCD like normal and having it create the sealed secret tool

Once the tool is deployed, run the following commands while connected to the new cluster:
```
kubectl apply -f main.key
kubectl delete pod -n kube-system -l name=sealed-secrets-controller
```

Once the sealed-secrets-controller pod restarts, any sealed secrets should unseal automatically.