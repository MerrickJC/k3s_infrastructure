# Reloader

What does this app solve? A lot of applications only read their config/secrets at startup, so if the underlying `ConfigMap`/`Secret` is updated, the running Pod continues to use the old value until something restarts it. [Stakater Reloader](https://github.com/stakater/Reloader) watches `ConfigMap`/`Secret` objects for changes and if it detects a change it restarts the workloads that consume them. It does nothing unless a workload opts in via annotation and it doesn't watch anything by default.

## Usage

Add an annotation to the Deployment/StatefulSet/DaemonSet, not the Pod template. There are two ways to opt in:

### 1. Watch Everything The Workload Already References

For a given workload, if you want to have Reloader watch all of the `ConfigMap`/`Secret` used via `env`, `envFrom`, or a volume mount:

```yaml
metadata:
  annotations:
    reloader.stakater.com/auto: "true"
```

### 2. Watch One Specific `Secret`/`ConfigMap` By Name

For a given workload, if you only want to have Reloader reload the workload for some `Secret`/`ConfigMap` and not all of them, then you can specify the `Secret`/`ConfigMap` in the annotation:

```yaml
metadata:
  annotations:
    secret.reloader.stakater.com/reload: "my-secret-name-1,my-secret-name-2"
    configmap.reloader.stakater.com/reload: "my-configmap-name-1,my-configmap-name-2"
```

### In Helm Charts

Most charts expose an `annotations` key for the Deployment which is where you can put one of the above annotation styles. For example for SeaweedFS (see `apps/seaweedfs/values.yaml`):

```yaml
allInOne:
  annotations:
    secret.reloader.stakater.com/reload: seaweedfs-s3-config
```

## How it works

Reloader patches a hash of the `Secret`/`ConfigMap` as an annotation on the Pod templates. When the `Secret`/`ConfigMap` changes this changes the hash, which changes the annotation that is patched and Kubernetes detects this and triggers a normal rolling restart. No extra permissions or restart command needed.
