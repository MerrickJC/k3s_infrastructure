# JuiceFS S3 Gateway

Exposes the same JuiceFS filesystem that `apps/juicefs`'s `juicefs-sc` StorageClass is backed by (same Postgres `metaurl`) as an S3-compatible API, via the `juicefs-s3-gateway` chart. Used by `apps/kube-kleinkram` instead of talking to SeaweedFS directly.

## Why two CronJobs instead of the chart's own secret values

The chart's `secret:` values block would require `metaurl`/`access-key`/`secret-key` as plaintext in `values.yaml`, is an anti-pattern. `values.yaml` sets `secret.enabled: false` to skip the chart's own Secret template, but the Deployment still expects a Secret literally named `juicefs-secret` (hardcoded by the chart, not configurable), which the jobs below build instead.

1. [`secrets/juicefs-gateway-secret-job.yaml`](./secrets/juicefs-gateway-secret-job.yaml) copies `apps/juicefs`'s already-composed `juicefs-sc-secret` verbatim into `juicefs-secret`. The gateway's init container re-runs `juicefs format` on every pod start using these fields, idempotently. This secret needs the full field set (`name`/`metaurl`/`storage`/`access-key`/`secret-key`/`bucket`), not just `metaurl`.

   The chart also wires this same Secret's `access-key`/`secret-key` fields as `MINIO_ROOT_USER`/`MINIO_ROOT_PASSWORD` (the gateway's own S3-API superuser login) - this is the chart's intended design, not a workaround. In practice this means the gateway's root credential is the `juicefs-s3-credentials` SeaweedFS identity. That's fine because the root credential is never handed to any app and is only used internally by `juicefs-gateway-iam-job.yaml` below to bootstrap scoped per-app users.

2. [`secrets/juicefs-gateway-iam-job.yaml`](./secrets/juicefs-gateway-iam-job.yaml) uses the gateway's `mc admin` API to create the data/dbdumps/action-artifacts buckets (top-level directories, since `values.yaml` sets `options: --multi-buckets`) and two scoped IAM users on top of the root credential:
   - `kleinkram-juicefs-credentials`: `readwrite` policy, every bucket
   - `kleinkram-juicefs-artifacts-credentials`: custom policy scoped only to `action-artifacts`

### Why no Reloader integration

Reloader would normally be a good fit here (same pattern as `apps/seaweedfs`/`apps/argo-workflows`) but it isn't used since the `juicefs-s3-gateway` chart only exposes `podAnnotations`, which lands on `spec.template.metadata.annotations` whereas Reloader's trigger annotations (`reloader.stakater.com/auto`, `secret.reloader.stakater.com/reload`, etc.) only take effect on the Deployment's own `metadata.annotations`, which this chart doesn't expose a values field for. So a changed `juicefs-secret` (e.g. if `juicefs-s3-credentials` is ever rotated) needs a manual restart to take effect using `kubectl rollout restart deployment/juicefs-s3-gateway -n juicefs`.

## Rotating a kleinkram credential

Patch `kleinkram-juicefs-credentials` or `kleinkram-juicefs-artifacts-credentials` (in `secrets`) with `secret-generator.v1.mittwald.de/regenerate: "yes"` (see `apps/secrets/README.md`). `juicefs-gateway-iam-job.yaml`'s CronJob picks up the new value on its next run (within 15 minutes, or force it immediately with `kubectl create job --from=cronjob/juicefs-gateway-iam-builder -n juicefs juicefs-gateway-iam-builder-manual`) and re-registers the user with the new secret key. Kleinkram then needs to be reloaded too either via automatic reloader or manually so that it updates the credentials too.
