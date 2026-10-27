# Argo Workflows

Workflow engine used to run multi-step Kubernetes-native pipelines (e.g. ROS bag processing jobs). Deployed cluster-wide so any namespace can submit Workflows, and integrates with several apps already in this cluster instead of standing alone:

- **Auth**: the UI/API sit behind Dex OIDC (`server.sso`, `--auth-mode=sso`) instead of the chart's default raw-bearer-token login. Access level is decided per-user via [SSO RBAC](https://argo-workflows.readthedocs.io/en/latest/argo-server-sso/) impersonation. See the `ServiceAccount`/`rbac-rule` annotations in `manifest.yaml` for more information
- **Artifacts**: the default artifact repository is the cluster's SeaweedFS S3 gateway (`apps/seaweedfs`), using its own dedicated bucket and S3 identity
- **Scheduling**: Argo Workflow pods are raw `Pod`s and can be picked up by Kueue's `pod` integration (see `apps/kueue/values.yaml`) if you label a Workflow's pod template with `kueue.x-k8s.io/queue-name`

## Retention

Finished Workflows are pruned automatically via `ttlStrategy`/`podGC` in `values.yaml` so they don't pile up in etcd. Archiving to Postgres for longer-term/searchable history is supported by the chart but left commented out in `values.yaml`. It can be enabled once a role/database exists for this app in `apps/postgresql`'s shared cluster.
