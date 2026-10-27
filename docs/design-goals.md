# Design Goals and Principles

This document collects the design goals and principles that shaped this repository's
architecture, and ties each one to a concrete, verifiable piece of implementation —
not just a stated intention. Sources are the written rationale in `docs/` and the
actual structure of `kubernetes/` and `.github/`.

Each section states the principle, quotes the primary evidence for *why* it was
adopted, and then points to the file(s) that prove it was actually built that way.

---

## 1. GitOps / Git as the single source of truth

**Principle:** The cluster's desired state lives entirely in this git repository.
Nothing about what is deployed should require tribal knowledge or manual
`kubectl` state that isn't reconstructable from the repo.

**Why:**
> "I have tried to make setup and configuration as fool-proof as possible. In doing
> so, I have automated several things and tried to achieve an almost entirely
> declarative GitOps setup." — `docs/kubernetes/deployment.md`

> "Having a GitOps based declarative setup should make redeploying easy... because
> the entire system can be spun up and shutdown in a simple way using what is
> already in the git repository." — `docs/kubernetes/deployment.md`

**Proof in the implementation:**
- `kubernetes/argocd-management/unified-automation.yaml` is an ArgoCD
  `ApplicationSet` with a `git` generator that walks `apps/*/config.yaml` and turns
  every match into a live `Application` — the repository *is* the cluster's
  declared state, not a side artifact of it.
- `docs/migration-guide.md` explicitly enumerates the small handful of things that
  *can't* live in git (K3s OIDC flags, the sealed-secrets private key, initial
  ArgoCD bootstrap) — the exception list itself is evidence of how far the "git is
  truth" principle was pushed.

---

## 2. Self-management (the system manages its own upgrades)

**Principle:** ArgoCD, the tool that manages the cluster, is itself deployed and
upgraded through the same GitOps pipeline it enforces on everything else — no
out-of-band bootstrap process for the manager itself after initial setup.

**Why:**
> "ArgoCD is used to self-manage ArgoCD. To achieve this you just need to
> bootstrap the deployment once and then it will be able to self-manage from
> there." — `docs/migration-guide.md`

> "the goal is to make a cloud system that is: easy to navigate and understand;
> self-managing." — `docs/kubernetes/deployment.md`

**Proof in the implementation:**
- `kubernetes/argocd-management/kustomization.yaml` pulls ArgoCD's own
  install manifest declaratively (`https://raw.githubusercontent.com/argoproj/argo-cd/v3.5.2/manifests/install.yaml`)
  alongside `unified-automation.yaml`, so ArgoCD reconciles its own version pin the
  same way it reconciles every app.
- `.github/renovate.json5` has a dedicated custom regex manager just for that pinned
  ArgoCD version, annotated: *"ArgoCD's version - arguably the single most
  consequential pin in this repo, since it self-manages every other app."* The
  `argocd-management` bump path also requires `dependencyDashboardApproval: true` —
  the blast-radius risk of self-management is treated as a first-class concern, not
  an afterthought.

---

## 3. Convention-over-configuration / zero-touch extensibility

**Principle:** Adding a new application to the cluster should require touching
exactly one new folder — no edits to any central manifest, CI script, or
dependency-bot config.

**Proof in the implementation:**
- `kubernetes/apps/README.md`: *"All helm charts should follow the
  general format shown by the [example](./example/) folder"* — `apps/example/` is
  a fully-commented, placeholder-only template documenting every field a
  `config.yaml` can declare (`hasHelm`, `helmGit`, `hasManifests`, `syncOptions`,
  `ignoreDifferences`, `labels`/`annotations`, `retry`, `preventDeletion`).
- The ApplicationSet generator in `unified-automation.yaml` uses a glob, not a
  hardcoded list:
  ```yaml
  files:
    - path: "kubernetes/apps/*/config.yaml"
    - path: "kubernetes/apps/example/config.yaml"
      exclude: true
  ```
  combined with a `goTemplate` that conditionally assembles `spec.sources` based on
  which keys (`hasHelm`/`helmGit`/`hasManifests`) are present — one generic template
  drives every app, rather than per-app hardcoding.
- `.github/renovate.json5` mirrors the identical `apps/*/config.yaml` glob for its
  custom managers, with the comment: *"a new OCI-based app needs zero Renovate
  config changes to be picked up, mirroring how the ArgoCD ApplicationSet itself
  auto-discovers new apps/<name>/ folders."* Two independent systems (deployment and
  dependency-bumping) honor the same convention without being told to agree.

---

## 4. Modularity / swappable, provider-agnostic components

**Principle:** Components tied to a specific vendor or cloud provider should be
isolated behind an abstraction, so the underlying implementation can be replaced
without touching the rest of the system.

**Why:**
> "Kubernetes scalability will only be provided for OpenStack, but the components
> used for this will be modular and replacable." — `docs/scope.md`

> "The specific choice of an S3-like object storage does not impact the
> configuration of the rest of the architecture, since the S3-like API is
> abstracted by JuiceFS." — `docs/scope.md`

**Proof in the implementation:**
- `kubernetes/apps/juicefs/` deploys the `juicefs-csi-driver` chart,
  exposed to consumers purely as a `StorageClass` — nothing downstream talks to the
  object store directly.
- `kubernetes/apps/seaweedfs/` is the concrete S3-like backend
  currently plugged in behind that abstraction.
- `kubernetes/apps/juicefs-s3-gateway/README.md`: *"Used by
  `apps/kube-kleinkram` instead of talking to SeaweedFS directly"* — a second layer
  of indirection reinforcing that consumers are wired to JuiceFS's abstraction, not
  to SeaweedFS specifics. Swapping the object-store backend only requires replacing
  `apps/seaweedfs/*`; `apps/juicefs/` and its consumers are untouched.

---

## 5. Secrets: no plaintext in git, with concerns cleanly separated

**Principle:** Secret handling is split into three single-purpose controllers
instead of one monolith, so that externally-sourced secrets, purely-internal
tokens, and cross-namespace distribution are each solved independently.

**Why:**
> "One of the challenges with defining everything using IaC in Git is that you
> don't want to commit plaintext representations of anything sensitive... This can
> be solved by encrypting the sensitive content and storing it in Git in this
> encrypted form." — `docs/kubernetes/sealed-secrets.md`

**Proof in the implementation:**
- `kubernetes/apps/secrets/README.md`: *"Every secret's source of
  truth lives in this app... and gets fanned out to other namespaces as needed.
  Three apps make this work"*:
  - `apps/secrets-sealed/` (Bitnami Sealed Secrets) — encrypted `SealedSecret`
    ciphertext safe to commit, for values sourced from outside the cluster.
  - `apps/secrets-generator/` (`kubernetes-secret-generator`) — *"generates a
    random value directly in-cluster for secrets whose value is an arbitrary
    agreed-upon token with no external source, so nothing has to be sealed at
    all."*
  - `apps/secrets-reflector/` (`reflector`) — mirrors a secret across namespaces
    via `reflection-allowed`/`reflection-auto-enabled` annotations, so a secret
    authored once can reach every consuming namespace without manual duplication
    (used downstream by `apps/juicefs/secrets/` and `apps/seaweedfs/secrets/`).
- `docs/kubernetes/sealed-secrets.md` is explicit about the limits of the model:
  *"Sealed secrets are not permanently secret! ... anyone with admin access to the
  cluster [can read them] via the kubectl commandline."* — the design goal is
  "safe to commit," not "secret forever," and the documentation says so plainly.

---

## 6. Identity-based, auditable, least-privilege cluster access

**Principle:** Access to the cluster should be tied to an individual's real
identity and scoped to the minimum privilege needed, rather than handed out as a
single shared credential.

**Why:**
> "By default, K3s only accepts client-certificate based auth for kubectl, which
> means the only way to grant someone cluster access is to hand them the admin
> kubeconfig (full cluster-admin, no per-person identity, no way to revoke a single
> person)... every kubectl command requires logging in with your GitHub account,
> requiring membership in the monashmotorsport GitHub org." —
> `docs/kubernetes/oidc-cluster-authentication.md`

**Proof in the implementation:**
- `docs/kubernetes/oidc-cluster-authentication.md` and
  `docs/kubernetes/argocd-oidc-authentication.md` both describe the same two-tier
  model implemented via Dex-backed OIDC + RBAC: any org member gets read-only
  access (excluding `Secret` objects), and only a named team gets `cluster-admin`.
- The same doc explicitly preserves a fallback: *"Never delete or rotate [the
  original admin kubeconfig] as part of this setup; it's your break-glass access if
  Dex, GitHub, or the tunnel ever has an outage"* — least-privilege is added
  additively, without removing the escape hatch.
- Dex itself is configured with Kubernetes-backed (not in-memory) storage
  specifically so pod restarts don't silently regenerate its signing key and
  invalidate every outstanding token cluster-wide — a resilience property required
  to make the identity system trustworthy enough to rely on.

---

## 7. CI as the only safety net (no staging environment)

**Principle:** Because every app syncs automatically straight to the live cluster,
pre-merge CI is the sole gate between a bad change and production — there is no
post-merge staging step to catch mistakes.

**Why / proof (the rationale and the mechanism are stated together in the code):**
- `kubernetes/argocd-management/unified-automation.yaml` applies
  `syncPolicy.automated: {prune: true, selfHeal: true}` to every generated
  `Application` unconditionally — it is set once, centrally, in the shared
  template, not per app. A grep for `automated` across all `apps/*/config.yaml`
  files returns zero matches, confirming no app opts out.
- `.github/workflows/helm-app-render-check.yml` / `.github/scripts/render_helm_apps.py`
  state the consequence directly: *"this is the only gate between a bad chart
  bump... and it going live with no post-merge staging step."*
- `.github/workflows/jenkins-jcasc-check.yml` goes further for Jenkins
  specifically, actually booting a containerized Jenkins with the rendered
  JCasC config and plugin set pre-merge — simulating a staging environment
  entirely inside CI because none exists at runtime.
- `.github/renovate.json5`: *"Every dependency here reaches the live cluster the
  moment a PR merges... Renovate must never merge on its own; a human + passing CI
  is the only gate."* → `automerge: false` is set globally, with extra
  `dependencyDashboardApproval: true` gates for the highest-blast-radius bumps
  (`cloudnative-pg`, `cert-manager`, `argocd-management`).

---

## 8. Supply-chain and dependency security monitoring

**Principle:** Dependency risk should be monitored continuously and from multiple
angles, including sources that generic dependency bots don't cover.

**Proof in the implementation:**
- `.github/renovate.json5` enables `osvVulnerabilityAlerts: true` for
  OSV.dev-based scanning of Helm chart and plugin dependencies.
- `.github/workflows/jenkins-plugin-security-check.yml` runs on a schedule (not
  per-PR) specifically because *"Jenkins plugin security advisories are a category
  Renovate structurally cannot cover"* — `.github/scripts/check_jenkins_plugin_security.py`
  checks pinned plugin versions against Jenkins' own live Update Center
  security-warnings feed and keeps a single GitHub issue continuously up to date,
  filling the exact gap the first tool leaves open.

---

## 9. Reproducibility and portability (migration/lift-and-shift friendliness)

**Principle:** The whole system should be redeployable to a new cluster, or
recoverable after the original team has moved on, using nothing but what's in git.

**Why:**
> "It would also support a GitOps approach to server management, which would
> improve reproducibility and ensure that the cluster does not become
> unmaintainable after current team members leave." — `docs/architecture/goals-for-mms.md`

> "MMS may or may not have long-term reliable cloud platforms to deploy on... a
> system that is no longer running will be left unmaintained for years and then
> eventually will need to be redeployed." — `docs/kubernetes/deployment.md`

**Proof in the implementation:**
- `docs/migration-guide.md` is a dedicated, step-by-step document for moving this
  exact setup to a new cluster, including concrete bulk-replace instructions
  (`merrickcampbell.au` → new domain; the git remote URL → new repo) — the
  portability goal is operationalized as an actual runbook, not just an aspiration.
- `kubectl apply -k ./kubernetes/argocd-management` (documented in
  the root `CLAUDE.md` and the migration guide) is the entire re-bootstrap command
  once the few non-git prerequisites (OIDC flags, sealed-secrets key) are in place.

---

## 10. Designed for non-specialist (robotics, not cloud) engineers

**Principle:** The team maintaining this system are robotics engineers first, not
cloud engineers — the architecture should be legible and self-explanatory to them,
not just to its original author.

**Why:**
> "The team members in MMS who can code are basically all robotics engineers, not
> cloud engineers... So the goal is to make a cloud system that is: easy to
> navigate and understand; self-managing." — `docs/kubernetes/deployment.md`

> "I hate when you can't tell what is happening. Trying to reason about cloud
> systems sucks enough as it is, but not knowing what services have been applied
> and how things are running makes it a living hell." — `docs/kubernetes/deployment.md`

**Proof in the implementation:**
- ArgoCD's UI is the chosen mechanism precisely because, per the same doc, it
  *"keeps track of variations of the state of the cluster from the desired state
  and provides an intuitive visualisation of this"* — observability of drift is
  treated as a usability requirement for a non-specialist team, not a nice-to-have.
- The `apps/<name>/config.yaml` + `README.md` convention (Section 3) means a team
  member can understand or add an app by copying `apps/example/` and filling in a
  handful of documented fields, without needing to understand ArgoCD's
  `ApplicationSet`/Helm internals.

---

## 11. Cost-efficiency and resource elasticity

**Principle:** Idle infrastructure should cost nothing (or close to it); compute
should scale with actual demand rather than being provisioned for peak load
permanently.

**Why:**
> The Jenkins server only processes a handful of pull requests per day and sits
> idle the rest of the time; an autoscaling cluster that provisions nodes when
> jobs are scheduled and scales back down once they're no longer needed avoids
> paying for that idle time. — `docs/architecture/goals-for-mms.md`

**Proof in the implementation:**
- Jenkins agents are deployed via the Kubernetes plugin rather than as
  always-on static agents, directly implementing the scale-to-zero pattern
  described above.
- `docs/architecture/making-things-free-for-mms.md` grounds this in a concrete
  scale-to-zero mechanism (KEDA-driven bursting into paid cloud compute only
  while a job queue has work) rather than treating cost-efficiency as an
  abstract goal.

---

## 12. Data locality and caching as a performance differentiator

**Principle:** Repeated access to the same data (ROS bags) should not re-trigger
a redundant download — this was identified as a specific weakness in comparable
tools and designed against explicitly.

**Why:**
> "If 10 actions in a row utilise the same data, then all 10 actions will
> re-download that data." (critique of the competing tool Kleinkram) —
> `docs/contribution/comparison-to-others.md`

> "My tool should be significantly faster than Kleinkram, since my tool will cache
> the ROS bags the first time they are downloaded and won't need to then
> re-download them." — `docs/contribution/comparison-to-others-testing.md`

**Proof in the implementation:**
- The JuiceFS layer (Section 4) provides exactly this caching behavior as a
  byproduct of its filesystem semantics — bags mounted once via the CSI driver
  stay resident rather than being re-fetched per job, which is the concrete
  mechanism behind the comparative performance claim above.

---

## 13. Explicit scope boundaries

**Principle:** What the system is *not* responsible for should be stated as
clearly as what it is, so that out-of-scope decisions (e.g. "any S3-compatible
store works") don't get silently re-litigated later.

**Why / proof:**
> "In Scope: Kubernetes scalability will only be provided for OpenStack...
> Out Of Scope: The choice of S3-like object storage. It is assumed that whoever
> deploys this overall tool will make their own selection..." — `docs/scope.md`

This document is the direct justification referenced by Section 4 (JuiceFS
abstraction) and is itself evidence that scope decisions and the abstractions
that enable them were designed together, not independently.

---

## Note on sourcing

This document was compiled from `docs/` (the primary source of stated design
rationale), the structure of `kubernetes/apps/` and
`argocd-management/`, and `.github/` (CI workflows, scripts, and
`renovate.json5`).
