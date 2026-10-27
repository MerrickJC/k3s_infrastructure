# Deployment Architecture Options

This document compares the deployment architectures considered for running
BagAnTo for MMS, and the constraints that ruled a purely self-hosted or purely
cloud setup out in favour of the hybrid model this repository implements.

## Implementation Constraints

**Self-hosting:**
- The cluster can't be physically hosted at Monash — this would violate
  Monash's cybersecurity policy around self-hosted servers on university
  premises.
- Team members may have old hardware they're willing to donate, but it would
  be geographically dispersed across personal homes, with unreliable and
  inconsistent internet connections between nodes.

**Storage:**
- The team generates on the order of 1TB of ROS bags per year, and can't
  afford to store the full multi-year history anywhere other than existing
  on-premise storage.

## Three Architectures

### Entirely Self-Hosted

**Pros:**
- No ongoing costs, and no risk of surprise billing.
- Large re-indexing jobs cost time, not money.
- Can run on the same hardware (including robotics hardware) that will run in
  production, improving hardware integration testing.

**Cons:**
- Limited compute can make job queues slow.
- Limited storage likely requires buying more physical storage devices.
- Can't host servers at the Makerspace.
- Network limitations depend on the geographic spread of the servers.

**Achievability:** Possible, but would likely require running on laptops and
devices in team members' homes — shifting operational costs onto individuals
and introducing security risk from running infrastructure on personal home
networks. It would also likely require buying storage the team doesn't
already own, and would need significant data replication to tolerate any one
person's unreliable home network without data loss or outages.

### Hybrid-Cloud Architecture

Local compute, cloud storage.

**Pros:**
- Scalable, fast, reliable, redundant, accessible storage.
- No need to develop a server-scaling strategy or pay for underutilised
  servers.
- Can still use existing compute hardware (including production robotics
  hardware) for integration testing.

**Cons:**
- Ongoing costs for storage (per GB), egress (per GB), and storage queries.
- Risk of surprise costs from actions taken without understanding their
  billing impact.
- Re-indexing large amounts of data becomes expensive: egress costs apply to
  every GB not already in a local cache, so a cache only ever reduces the
  cost by the amount of data it can hold — not eliminate it.

**Achievability:** Achievable, provided data-analysis actions that move large
volumes of data from cloud to local compute are carefully considered. A cache
sized to cover most routine analysis workloads makes this a reasonable
tradeoff.

### Entirely Cloud

**Pros:**
- Low latency between compute and storage.
- No egress cost reading data from storage in the same region as compute.
- Highly scalable storage and compute.
- Likely faster networking than achievable on MMS's budget.

**Cons:**
- Expensive storage and compute.
- High risk of surprise costs from launching too many jobs.
- Reduces the incentive for developers to run bag testing, due to high
  per-run cost.
- Can't test algorithms on the same hardware they'll eventually run on,
  unless that hardware happens to be available through a cloud provider.

## Conclusion: Hybrid With Edge Nodes

In a fully cloud-based architecture, data-locality-aware caching isn't worth
the complexity — intra-datacentre data transfer is fast enough that it's
negligible either way. In a fully self-hosted architecture, locality-aware
caching matters only if the network is slow or unreliable; if it is, workers
blocked waiting on a file download are wasting allocated resources, and
deleting a file immediately after use (rather than caching it) wastes
network capacity that will likely be needed again shortly after.

Locality-aware scheduling matters most for ROS re-simulation specifically,
since a bag needs to already be resident on the device before replay starts —
replay fails otherwise, as reading only the file's footer and index isn't
enough (see
[MCAP vs. ROS1 bag index performance](https://foxglove.dev/blog/mcap-vs-ros1-bag-index-performance)
and the [MCAP spec](https://mcap.dev/spec)).

The architecture this repository implements is the hybrid model: core
services (database, storage, orchestration) run as if cloud-hosted — whether
that cloud is a commercial provider or a self-hosted datacentre with fast,
cheap internal transfer — while a smaller number of edge nodes exist
specifically for hardware-in-the-loop verification. Those edge nodes incur a
real egress cost when pulling data, so they're reserved for essential
workloads, or for situations where they already have the relevant data
cached locally from a previous job.

**Open question:** whether an existing hardware-in-the-loop framework for
robotics systems could be adopted here instead of building this scheduling
logic from scratch.
