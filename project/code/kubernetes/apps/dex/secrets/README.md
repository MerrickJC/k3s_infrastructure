# Setup Requirements
Dex requires creating client secrets that must be known by both the Dex pod and the client pod. Since each sealed secret can only be sealed for a single namespace and a secret can only be read in the same namespace it is in, you will need to seal each secret twice, once for the Dex namespace and once for the client's namespace. The alternative to this is a convoluted setup that reduces isolation between namespaces. 

> **Note**: secrets are namespace scoped, meaning there won't be a conflict between the secrets' names and so you don't have to change anything other than the namespaces

For example:
```
kubectl create secret generic headlamp-dex-client-secret --from-literal=HEADLAMP_DEX_CLIENT_SECRET="ABCD" -n headlamp --dry-run=client -o yaml | kubeseal --format yaml > headlamp-dex-client-secret.yaml
```
```
kubectl create secret generic headlamp-dex-client-secret --from-literal=HEADLAMP_DEX_CLIENT_SECRET="ABCD" -n dex --dry-run=client -o yaml | kubeseal --format yaml > headlamp-dex-client-secret.yaml
```

I would recommend replacing "ABCD" with the output of `openssl rand -base64 32`. **REMEMBER both secrets must have the same value**, you are only generating the sealed secret twice to handle the two different namespaces.

More information about sealed secrets can be [found here](../../../../../../docs/kubernetes/sealed-secrets.md).

It is important that one of the secrets is created for the dex namespace and that the other is created for the client's namespace (whatever namespace an application trying to provide dex authentication is deployed in).

In the event that the secret needs to be rotated, you will have to regenerate both secrets

## Naming Convention
I have chosen an arbitrary naming convention:
- Dex namespace:
    - ```<client>-dex.yaml```
- Client's namespace:
    - ```<client>-client.yaml```
