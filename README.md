# Overview

This is a self-hosted ROS bag database and analysis platform, built for Monash Motorsport (MMS) and currently deployed on a self-hosted K3s cluster.

This repository is almost entirely **declarative GitOps configuration** for a
Kubernetes cluster managed by [ArgoCD](https://argo-cd.readthedocs.io/) —
there is no application source code to build here. Everything the cluster
runs is described as YAML (Helm values, ArgoCD app configs, sealed secrets,
Kustomize) under `kubernetes/`, and ArgoCD keeps the live
cluster in sync with whatever is merged to `main`.

## Why this exists

Object storage, job orchestration, and ROS re-simulation each have their own
cost/complexity tradeoffs for a small, self-hosted, student-run team — see
`docs/architecture/deployment-models.md` for the comparison that led to the
hybrid architecture implemented here, and `docs/design-goals.md` for the
design principles that shaped the implementation itself (GitOps-as-truth,
ArgoCD self-management, swappable storage/compute backends, least-privilege
access, no-staging CI gating, etc.), each tied back to the file that proves
it was actually built that way.

## Repository layout

- `kubernetes/apps/<app-name>/` — one folder per deployed
  application. Each app is auto-discovered by an ArgoCD `ApplicationSet` —
  see `kubernetes/apps/README.md` for the per-app config
  convention (`config.yaml` + `values.yaml`), and `apps/example/` for an
  annotated template.
- `kubernetes/argocd-management/` — bootstraps ArgoCD and lets
  it self-manage its own upgrades through the same pipeline it enforces on
  every other app.
- `docs/` — architecture rationale, the migration/redeployment guide, and
  Kubernetes how-tos (kubectl access, sealed secrets, OIDC login).
- `.github/scripts/` + `.github/workflows/` — CI validation for the
  Kubernetes config (Helm chart render checks, Jenkins JCasC checks, plugin
  security scanning).

## Getting started

Cluster access requires an OIDC login via Dex — see
`docs/kubernetes/oidc-cluster-authentication.md`.

```bash
# Validate every app's Helm chart still renders (mirrors the CI check)
python .github/scripts/render_helm_apps.py kubernetes/apps

# Bootstrap or re-apply ArgoCD's self-management on a fresh cluster
kubectl apply -k ./kubernetes/argocd-management
```

See `docs/migration-guide.md` for the full process of redeploying this setup
to a new cluster, and the short list of things that can't live in git (K3s
OIDC flags, the sealed-secrets private key, initial ArgoCD bootstrap).

## Adding a new application

Copy `kubernetes/apps/example/` to a new folder and fill in
`config.yaml` — no other file in the repository needs to change. The
ApplicationSet, Renovate, and CI all discover new apps via the same
`apps/*/config.yaml` glob. See `kubernetes/apps/README.md` for
details.

## Documentation

- `docs/design-goals.md` — design principles behind this repository, each
  backed by a quote and a pointer to the implementing file.
- `docs/architecture/` — deployment architecture options, Nectar/Jenkins
  scaling goals, cost strategy, and the Cloudflare Tunnel setup.
- `docs/contribution/` — comparison against the existing tool (Kleinkram)
  this project improves on, and the test plan used to validate that claim.
- `docs/database/` — database entity design notes and the exported schema.
- `docs/justifications/` — standalone rationale docs for specific design
  decisions (e.g. why a container orchestrator is needed at all).
- `docs/kubernetes/` — operational how-tos: cluster access, sealed secrets,
  OIDC for kubectl and ArgoCD.
- `docs/migration-guide.md` / `docs/scope.md` — redeployment runbook and
  explicit in/out-of-scope boundaries.
