# Setup Requirements

`values.yaml` injects three secrets into the Jenkins controller container as environment variables, which the JCasC config embedded in that same file then reads via JCasC's `${VAR}` substitution. You need to create each SealedSecret yourself with the real value and commit the resulting YAML into this folder.

For each secret below, replace `<value>` with the real secret and run the command. This encrypts the value client-side with `kubeseal`, so only the in-cluster controller can decrypt it - see [../../../../../docs/kubernetes/sealed-secrets.md](../../../../../docs/kubernetes/sealed-secrets.md) for more information.

## 1. GitHub App private key

Used by the `jenkins-api-key-for-github` credential (a `gitHubApp` JCasC credential, App ID `4633594`).

**This must be the App's private key (a PEM file), not the Client ID or Client secret shown on the same GitHub App settings page.** The Client ID/secret pair is only used for GitHub's "Sign in with GitHub App" user-facing OAuth flow but the github-branch-source plugin's `gitHubApp` credential authenticates as the app itself via a JWT signed with the private key, so it never touches the client secret. Sealing the client secret here would look superficially fine (kubeseal doesn't validate the content) but would fail authentication at runtime.

**Required repository permissions**, per the [github-branch-source plugin's own GitHub App guide](https://github.com/jenkinsci/github-branch-source-plugin/blob/master/docs/github-app.adoc) - set these on the App itself (GitHub App settings > Permissions & events), not on this Jenkins config:

| Permission | Level | Why |
|---|---|---|
| Metadata | Read-only | Mandatory baseline for any GitHub App |
| Contents | Read-only | Clone/checkout and read `Jenkinsfile` during `git fetch` (bump to Read & write only if a job needs to push, e.g. tagging releases) |
| Commit statuses | Read & write | Report build pass/fail back to commits |
| Pull requests | Read-only | Multibranch/PR discovery and scanning |

Don't grant more than this without a concrete reason - e.g. Administration, Actions, or Issues aren't needed for anything this credential does. Also install the App only on the specific repositories Jenkins builds, not org-wide.

To get the key: on the GitHub App's settings page, "Generate a private key" downloads a `.pem`. Convert it to PKCS8 before using it (the plugin requires this format):

```bash
openssl pkcs8 -topk8 -inform PEM -outform PEM -in downloaded-key.pem -out converted-github-app.pem -nocrypt
```

Then seal it with `--from-file`, not `--from-literal` - the key is multi-line PEM content, and `--from-literal` is prone to mangling newlines/escaping for multi-line values:

```bash
kubectl create secret generic jenkins-github-api-token --from-file=JENKINS_GITHUB_TOKEN=converted-github-app.pem -n jenkins --dry-run=client -o yaml | kubeseal --format yaml > jenkins-github-api-token.yaml
```

## 2. Google Chat webhook secret

Used by the "Pull Request Status" Google Chat webhook credential.

```bash
kubectl create secret generic jenkins-google-chat-secret --from-literal=JENKINS_GOOGLE_CHAT_SECRET="<value>" -n jenkins --dry-run=client -o yaml | kubeseal --format yaml > jenkins-google-chat-secret.yaml
```

## 3. Dex OIDC client secret

Used by the `oic` security realm to log into Jenkins via Dex. Unlike the two secrets above, this one is a Dex client secret shared between two components in two namespaces (Dex itself, and Jenkins), so it must be **sealed twice** - once per namespace, both with the same value - following the convention documented in [../../dex/secrets/README.md](../../dex/secrets/README.md). The output files belong in `apps/dex/secrets/`, not here, matching every other Dex client (headlamp, argocd, etc):

```bash
kubectl create secret generic jenkins-dex-client-secret --from-literal=JENKINS_DEX_CLIENT_SECRET="<value>" -n dex --dry-run=client -o yaml | kubeseal --format yaml > ../../dex/secrets/jenkins-dex.yaml
```
```bash
kubectl create secret generic jenkins-dex-client-secret --from-literal=JENKINS_DEX_CLIENT_SECRET="<value>" -n jenkins --dry-run=client -o yaml | kubeseal --format yaml > ../../dex/secrets/jenkins-client.yaml
```

Dex expects this secret for the `jenkins` static client in Dex's own config (`apps/dex/values.yaml`). It reads `JENKINS_DEX_CLIENT_SECRET`.

## Rotating a secret

Re-run the matching command above with the new value and commit the updated file - see [../../../../../docs/kubernetes/sealed-secrets.md](../../../../../docs/kubernetes/sealed-secrets.md#rotating-a-secret) for why the ciphertext looks completely different each time even for the same value.

The Jenkins controller pod only picks up the new env var on its next restart, and **ArgoCD/the sealed-secrets controller doesn't restart running pods for you** - you'll need to find a safe way to restart the Jenkins pod yourself.
