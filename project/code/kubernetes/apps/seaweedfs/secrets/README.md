# Setup Requirements

`values.yaml` points `allInOne.s3.existingConfigSecret` at a Secret named `seaweedfs-s3-config`. `seaweedfs-s3-config-job.yaml` in this folder builds the required Secret automatically based on the value of other Secrets.

## How the secret gets built

`seaweedfs_s3_config` holds a single JSON document with one identity per consumer. This means the current one Secret per consumer doesn't work since multiple Secrets need to be combined into a single Secret for seaweedfs. `existingConfigSecret` only supports mounting one file, so every identity that needs to authenticate to SeaweedFS has to live in the same `identities` array.

This can't be produced by `secret-generator` or `SecretTemplate` alone since it requires combining two independently-generated credential pairs into one structured file. None of the tools in the cluster currently support embedding a generated Secret value inside a larger static string Secret, so it's composed by a `CronJob`:

1. Every identity's leaf credentials Secret (e.g. [`apps/secrets/generated/kleinkram-backend-s3-credentials.yaml`](../../secrets/generated/kleinkram-backend-s3-credentials.yaml), [`apps/secrets/generated/zot-s3-credentials.yaml`](../../secrets/generated/zot-s3-credentials.yaml)) is generated in the `secrets` namespace and reflected into every namespace that needs it, including `seaweedfs`. `zot-s3-credentials` is also reflected into `zot` as-is for Zot's own pod to consume
2. [`seaweedfs-s3-config-job.yaml`](./seaweedfs-s3-config-job.yaml) reads each reflected copy from its own (`seaweedfs`) namespace and writes the composed `identities` JSON directly into `seaweedfs-s3-config` in this namespace. This runs every 15 minutes.

### Why a CronJob instead of a one-shot Job

A normal Kubernetes `Job` could achieve the same, but if the underlying Secrets changed, this would not be reflected into the combined Secret and would remain stale until the original Job was retriggered. This was deemed undesirable because it could leave to confusing stale state errors.

Running it as an idempotent `CronJob` instead removes the change of the combined Secret being stale (can only be stale for up to 15 minutes before the CronJob re-runs). Every 15 minutes it recomposes `seaweedfs-s3-config` from whatever the leaf secrets currently contain. It then uses `kubectl apply` to apply the new Secret, which will only change the Secret in the cluster if there is a difference (which there won't be most of the time).

Since SeaweedFS doesn't hot-reload `-s3.config`, we use [`apps/reloader`](../../reloader/config.yaml) (Stakater Reloader) to restart the SeaweedFS deployment when a Secret change is detected.

### Adding a new S3 identity

The compose script in `seaweedfs-s3-config-job.yaml` is data-driven specifically so this doesn't require editing hand-escaped JSON:

1. Add a new generated credentials Secret under `apps/secrets/generated/` (copy `kleinkram-backend-s3-credentials.yaml`'s shape and use the same `secret-generator.v1.mittwald.de/autogenerate: AWS_ACCESS_KEY_ID,AWS_SECRET_ACCESS_KEY` annotations but with a different `metadata.name`), making sure `seaweedfs` is included in its `reflector.v1.k8s.emberstack.com/reflection-allowed-namespaces` list
2. Add that Secret's name to the `resourceNames` list on the `seaweedfs-s3-config-builder-read` Role in `seaweedfs-s3-config-job.yaml` (RBAC is allow-listed per-secret, so a new identity needs an explicit
   grant)
3. Add one line to the `IDENTITIES` table inside the CronJob's script: `<identity-name> <leaf-secret-name> <actions>`. There is a comment above that table for the actions syntax (unscoped vs. bucket-scoped).

## Rotating a key

Patch the relevant generated secret with `secret-generator.v1.mittwald.de/regenerate: "yes"` (see `apps/secrets/README.md` for more information). From there the `seaweedfs-s3-config-builder` CronJob picks up the new value on its next run (within 15 minutes or you can run `kubectl create job --from=cronjob/seaweedfs-s3-config-builder -n seaweedfs seaweedfs-s3-config-builder-manual` to force an immediate run), and Reloader restarts the SeaweedFS pod once `seaweedfs-s3-config` actually changes, since the pod only picks up the file on restart. No manual Job deletion or pod restart needed.
