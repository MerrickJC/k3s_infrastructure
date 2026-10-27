# JuiceFS S3 Gateway

Exposes a JuiceFS filesystem (Postgres `metaurl` + SeaweedFS-backed object storage) as an S3-compatible API. Used by `apps/kube-kleinkram` instead of talking to SeaweedFS directly.

Runs as a DaemonSet (one gateway pod per node, not a single shared Deployment) so that each node's applications can read/write through a gateway instance co-located on that same node, with its own local disk cache absorbing repeat reads before falling back to the S3 backend. The workload is hand-authored in `manifest.yaml` rather than via the upstream `juicefs-s3-gateway` Helm chart, because that chart only ships a single-replica Deployment and there's no toggle for a DaemonSet. The `manifest.yaml` initContainer/container commands otherwise mirror the chart's own templates for parity (same image, same `juicefs format`/`juicefs gateway` invocation, same env wiring).

## Per-node routing: `internalTrafficPolicy: Local`

The Service sets `spec.internalTrafficPolicy: Local`, which makes kube-proxy only route a pod's request to the gateway instance on that pod's own node (never a different node). This means that applications on a node don't have to communicate across nodes to communicate with the object storage and downstream applications like `kube-kleinkram`, the Traefik `IngressRoute`, or the IAM-bootstrap CronJob below don't require any configuration changes and all just keep hitting the same Service name/port as before.

## Per-node cache

`manifest.yaml`'s gateway container mounts a `hostPath` volume (`/var/lib/juicefs-gateway-cache` on the node, `type: DirectoryOrCreate`) at `/var/jfsCache`, and passes `--cache-dir=/var/jfsCache --cache-size=102400` (1024800 MiB = 100 GiB) to `juicefs gateway`. `DirectoryOrCreate` means no manual per-node setup is needed, including under cluster autoscaling. Note JuiceFS's `--free-space-ratio` (default `0.1`) can still evict cache early if the node's underlying disk drops below 10% free, independent of the 100GiB cap - only relevant if this path shares a disk with other node workloads.

## Secret composition instead of the chart's own secret values

A `secret:` values block would require `metaurl`/`access-key`/`secret-key` as plaintext in a values file which is an anti-pattern. The hand-authored `manifest.yaml` instead expects a Secret literally named `juicefs-secret` (the DaemonSet's `secretKeyRef`s hardcode that name).

1. [`secrets/juicefs-gateway-secret-job.yaml`](./secrets/juicefs-gateway-secret-job.yaml) composes `juicefs-secret` directly from the generated SeaweedFS S3 identity (`juicefs-s3-credentials`) and the generated Postgres role password (`juicefs-postgres-credentials`), both reflected into this namespace. The gateway's init container re-runs `juicefs format` on every pod start using these fields, idempotently.

   The DaemonSet also wires this same Secret's `access-key`/`secret-key` fields as `MINIO_ROOT_USER`/`MINIO_ROOT_PASSWORD` (the gateway's own S3-API superuser login) - this mirrors the chart's original design, not a workaround. In practice this means the gateway's root credential is the `juicefs-s3-credentials` SeaweedFS identity. That's fine because the root credential is never handed to any app and is only used internally by `juicefs-gateway-iam-job.yaml` below to bootstrap scoped per-app users.

2. [`secrets/juicefs-gateway-iam-job.yaml`](./secrets/juicefs-gateway-iam-job.yaml) uses the gateway's `mc admin` API to create the data/dbdumps/action-artifacts buckets (top-level directories, since `manifest.yaml` passes `--multi-buckets`) and two scoped IAM users on top of the root credential:
   - `kleinkram-juicefs-credentials`: `readwrite` policy, every bucket
   - `kleinkram-juicefs-artifacts-credentials`: custom policy scoped only to `action-artifacts`

## Rotating a kleinkram credential

Patch `kleinkram-juicefs-credentials` or `kleinkram-juicefs-artifacts-credentials` (in `secrets`) with `secret-generator.v1.mittwald.de/regenerate: "yes"` (see `apps/secrets/README.md`). `juicefs-gateway-iam-job.yaml`'s CronJob picks up the new value on its next run (within 15 minutes, or force it immediately with `kubectl create job --from=cronjob/juicefs-gateway-iam-builder -n juicefs juicefs-gateway-iam-builder-manual`) and re-registers the user with the new secret key. Kleinkram then needs to be reloaded too either via automatic reloader or manually so that it updates the credentials too.
