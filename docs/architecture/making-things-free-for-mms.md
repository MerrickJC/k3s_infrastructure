# Keeping Running Costs Near Zero For MMS

MMS is a student team with no sustained budget for cloud infrastructure, so the
architecture needs to default to self-hosted compute and storage wherever
possible, and only reach for paid cloud resources for the specific workloads
that genuinely need them.

## Self-hosting as the primary strategy

The core services (the Postgres database, the API, job orchestration) are
cheap enough to run continuously on modest hardware — a single small server is
enough. This can be:

- MMS's existing ARDC Nectar allocation (see `docs/architecture/goals-for-mms.md`),
  which is an academic compute grant rather than a personal account
- Donated hardware the team already has access to, running wherever the team is
  permitted to host a server (not on Monash premises, due to Monash's
  cybersecurity policy around self-hosted servers).

## Bursting into paid cloud compute for heavy workloads

Running ROS re-simulation is compute-intensive and spiky — it doesn't make
sense to keep that capacity provisioned 24/7. For workloads like this, the
cost-effective pattern is to scale to zero when idle and burst into on-demand
cloud compute (billed normally, under the account's own terms) only when a job
needs to run. [KEDA](https://keda.sh/) (Kubernetes Event-Driven Autoscaling)
can drive this: a self-hosted cluster that scales worker nodes up using cloud
capacity when the job queue has work, and back down to the self-hosted
baseline when it doesn't, so the team only pays for compute while a
re-simulation is actually running.

## Storage cost tradeoffs

Cloud object storage is the main recurring cost to watch. Per-GB storage,
egress, and request pricing mean that storing the team's full multi-year bag
history (on the order of multiple TB) in cloud storage long-term is
significantly more expensive than keeping the primary copy self-hosted and
using cloud storage selectively — e.g. as a cache or staging layer for
specific analysis jobs rather than the system of record. This is the same
reasoning behind the JuiceFS abstraction described in `docs/scope.md`: the
object-storage backend is swappable, so the team isn't locked into whichever
provider happens to be cheapest (or free) today.
