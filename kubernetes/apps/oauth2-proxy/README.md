# Shared SSO Gateway

One `oauth2-proxy` instance, backed by one shared Dex client, gates every app that wants Dex-based login via a Traefik `forwardAuth` Middleware. Login is shared across every protected app (`cookie-domain: .merrickcampbell.au` in [values.yaml](./values.yaml)): signing into one gives you a session on all of them.

Cross-namespace service references (every protected app's `/oauth2` route needs to reach this Service from its own namespace) require `providers.kubernetesCRD.allowCrossNamespace: true`, set once cluster-wide in `apps/traefik/manifest.yaml`.

## Protecting a new app

1. Add the app's callback URL to the `oauth2-proxy` client's `redirectURIs` in `apps/dex/values.yaml`. Dex only accepts exact, pre-registered redirect URIs, so this is required to be modified:
   ```yaml
   - id: oauth2-proxy
     redirectURIs:
       - "https://kueueviz.merrickcampbell.au/oauth2/callback"
       - "https://<new-app>.merrickcampbell.au/oauth2/callback" # add this line
   ```
2. Copy the `Middleware` (forwardAuth) block from `apps/ingress/routes/kueueviz.yaml` into the new app's own route file, changing only `metadata.namespace` to the new app's namespace.It's otherwise identical for every app: `forwardAuth.address` always points at the one shared oauth2-proxy Service, and `authSigninURL: /oauth2/start` is deliberately relative so it resolves against whichever host the browser is on.
3. In that app's `IngressRoute`, add the `/oauth2` passthrough route (unguarded, so the login flow itself isn't blocked by the middleware) and referencing the shared Service cross-namespace (`name: oauth2-proxy`, `namespace: oauth2-proxy`, `port: 80`) and attach the Middleware to whichever routes should require login.

Nothing in `apps/oauth2-proxy` itself needs to change. `extraArgs` has no fixed `redirect-url`, so oauth2-proxy derives the OAuth callback from each request's own Host header, and `whitelist-domain: .merrickcampbell.au` already covers any new subdomain under this domain.

## Secrets

- `apps/secrets/generated/dex-oauth2-proxy-client-token.yaml`: the one shared OIDC client-id/client-secret pair, reflected into `dex` and `oauth2-proxy`.
- `apps/secrets/generated/oauth2-proxy-cookie-secret.yaml`: session cookie encryption key, internal to `oauth2-proxy` only.

Both use lower-hyphenated keys (`client-id`/`client-secret`/`cookie-secret`) so they can be wired straight into oauth2-proxy's `extraEnv` (see `values.yaml`) and Dex's `envVars` without any modification.
