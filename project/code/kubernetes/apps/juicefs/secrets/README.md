# Setup Requirements

`values.yaml` points `storageClasses[0].existingSecret` at a Secret named `juicefs-sc-secret`. `juicefs-sc-secret-job.yaml` in this folder builds the required Secret automatically from other Secrets.

## How the secret gets built

The juicefs-csi-driver chart's `storageClasses[].existingSecret` only supports mounting one Secret, and that Secret has to contain every backend field JuiceFS needs in one place, which includes: the filesystem name, the Postgres `metaurl`, and the SeaweedFS S3 `access-key`/`secret-key`/`bucket`. Those values come from two independently-generated credential pairs, both sourced from `apps/secrets` and reflected into the namespace that needs them (see `apps/secrets/README.md` for more details on this pattern):

1. [`apps/secrets/generated/juicefs-s3-credentials.yaml`](../../secrets/generated/juicefs-s3-credentials.yaml) generates the SeaweedFS S3 identity in the `secrets` namespace. This is also read directly by [`apps/seaweedfs/secrets/seaweedfs-s3-config-job.yaml`](../../seaweedfs/secrets/seaweedfs-s3-config-job.yaml) to authorize that identity against the `juicefs` bucket
2. [`apps/secrets/generated/juicefs-postgres-credentials.yaml`](../../secrets/generated/juicefs-postgres-credentials.yaml) generates the `juicefs` Postgres role's password in the `secrets` namespace and reflects it into `postgresql`, where [`apps/postgresql/juicefs-database.yaml`](../../postgresql/juicefs-database.yaml)'s `DatabaseRole` (which provisions the role/database themselves) requires it to live, per CNPG's same-namespace rule for `passwordSecret`
3. [`juicefs-sc-secret-job.yaml`](./juicefs-sc-secret-job.yaml) reads `juicefs-s3-credentials` from `secrets` and `juicefs-postgres-credentials` from `postgresql`, and writes the composed `juicefs-sc-secret` Secret directly into the `juicefs` namespace. This runs every 15 minutes to catch any changes in the underlying secrets

This is the same problem and the same solution as [`apps/seaweedfs/secrets/seaweedfs-s3-config-job.yaml`](../../seaweedfs/secrets/seaweedfs-s3-config-job.yaml).

### Why no Reloader integration

SeaweedFS's config job pairs with `apps/reloader` because SeaweedFS runs as a single long-lived Deployment that needs restarting to pick up config changes. JuiceFS mount pods are different since the CSI driver creates one pod per PV/PVC on demand and reads `juicefs-sc-secret` at mount time. Reloader can only target `Deployment`/`StatefulSet`/`DaemonSet` since they naturally have a rollout ability based on values in a spec.template but the JuiceFS mounts don't utilise one of these resources and therefore can't be targeted. Existing mounts need a manual pod restart (which triggers a remount) to pick up changed credentials.

## Rotating a key

Patch `juicefs-s3-credentials` or `juicefs-postgres-credentials` (both in `secrets`, with `juicefs-postgres-credentials` also reflected into `postgresql`) with `secret-generator.v1.mittwald.de/regenerate: "yes"` (see `apps/secrets/README.md`). The `juicefs-sc-secret-builder` CronJob picks up the new value on its next run (within 15 minutes, or force it immediately with `kubectl create job --from=cronjob/juicefs-sc-secret-builder -n juicefs juicefs-sc-secret-builder-manual`). Existing mounts won't see the change until their mount pod is restarted (see above).
