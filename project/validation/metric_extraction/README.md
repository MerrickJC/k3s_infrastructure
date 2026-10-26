# Metric extraction

One-shot scripts to pull benchmark figures for a fixed time window out of
the kube-prometheus-stack Prometheus (same TSDB Grafana's "Prometheus"
datasource reads from). Each script is self-contained and queries a single
metric category; run them individually.

## Requirements

- `kubectl` with access to the cluster (any context that can reach the
  `observability` namespace)
- `curl`
- `jq` (optional - falls back to `python3 -m json.tool`, then raw JSON)
- GNU `date` (comes with Git Bash on Windows)

## Usage

```bash
./01_avg_cpu_usage_cluster.sh
```

Each script opens its own `kubectl port-forward` to Prometheus and tears it
down on exit, so they're safe to run back-to-back or in parallel.

Every run also saves a result to `results/`, named after the script (e.g.
`results/01_avg_cpu_usage_cluster.json`). Scripts that issue more than one
query (09-12, 15) save one file per query with a suffix (e.g.
`results/09_network_upload_cluster_overlay.json`, `..._external.json`).
Re-running a script overwrites its previous result(s).

The saved file is the Prometheus response stripped down to just the
number(s) - the full response (status/resultType/timestamp/etc.) still
prints to the terminal for sanity-checking, but what lands on disk is:

- a bare number, for an unlabelled single-series result (e.g. the
  cluster-wide scripts): `1.622468888611712`
- a flat `{"<labels>": value, ...}` object, for a multi-series result (e.g.
  the per-namespace/per-pod scripts), keyed by that series' labels so you
  still know which row is which: `{"namespace=observability": 0.41,
  "namespace=kube-system": 0.0987}`

By default the window is the idle period **2026-10-09 13:00:00 ->
2026-10-09 21:00:00 UTC**, regardless of the local timezone of whoever runs
the script (Prometheus itself always stores/queries in UTC). Override
per-invocation if you need a different window or a non-UTC wall-clock time:

```bash
WINDOW_START="2026-10-09T13:00:00+10:00" WINDOW_END="2026-10-09T21:00:00+10:00" ./01_avg_cpu_usage_cluster.sh
```

## Scripts

| # | File | Metric |
|---|------|--------|
| 01 | `01_avg_cpu_usage_cluster.sh` | Average CPU usage, whole cluster (cores) |
| 02 | `02_avg_memory_usage_cluster.sh` | Average memory usage, whole cluster (bytes) |
| 03 | `03_avg_cpu_usage_per_namespace.sh` | Average CPU usage, per namespace (cores) |
| 04 | `04_avg_memory_usage_per_namespace.sh` | Average memory usage, per namespace (bytes) |
| 05 | `05_peak_1m_cpu_usage_cluster.sh` | Highest 1-minute-average CPU usage, whole cluster |
| 06 | `06_peak_1m_memory_usage_cluster.sh` | Highest 1-minute-average memory usage, whole cluster |
| 07 | `07_peak_1m_cpu_usage_per_namespace.sh` | Highest 1-minute-average CPU usage, per namespace |
| 08 | `08_peak_1m_memory_usage_per_namespace.sh` | Highest 1-minute-average memory usage, per namespace |
| 09 | `09_network_upload_cluster.sh` | Network upload, node-to-node (overlay) vs node-to-internet (heuristic) |
| 10 | `10_network_download_cluster.sh` | Network download, node-to-node (overlay) vs node-to-internet (heuristic) |
| 11 | `11_network_upload_per_namespace.sh` | Network upload, per namespace |
| 12 | `12_network_download_per_namespace.sh` | Network download, per namespace |
| 13 | `13_network_upload_per_pod.sh` | Network upload, per pod (labelled with node) |
| 14 | `14_network_download_per_pod.sh` | Network download, per pod (labelled with node) |
| 15 | `15_disk_io.sh` | Disk I/O: total/avg bytes read+written, avg IOPS (cluster-wide + per node) |
| 16 | `16_pvc_usage.sh` | PVC usage/capacity, per namespace+claim (bytes) |
| 17 | `17_pod_restarts_and_oom_kills.sh` | Container restarts and OOM kills, per pod |
| 18 | `18_pod_scheduling_latency.sh` | Pod scheduling latency: avg + p99 (seconds) |
| 19 | `19_apiserver_latency_and_errors.sh` | API server latency (avg + p99) and 5xx error rate |
| 20 | `20_node_ready_stability.sh` | Node `Ready` condition stability, per node |
| 21 | `21_network_errors_and_retransmits.sh` | Network interface errors + TCP retransmits |
| 22 | `22_observability_stack_footprint.sh` | Observability stack's own CPU/memory/TSDB cost |
| 23 | `23_avg_cpu_usage_per_pod.sh` | Average CPU usage, per pod (cores) - kleinkram / kleinkram-actions / juicefs only |
| 24 | `24_avg_memory_usage_per_pod.sh` | Average memory usage, per pod (bytes) - kleinkram / kleinkram-actions / juicefs only |
| 25 | `25_peak_1m_cpu_usage_per_pod.sh` | Highest 1-minute-average CPU usage, per pod - kleinkram / kleinkram-actions / juicefs only |
| 26 | `26_peak_1m_memory_usage_per_pod.sh` | Highest 1-minute-average memory usage, per pod - kleinkram / kleinkram-actions / juicefs only |
| 27 | `27_juicefs_seaweedfs_request_and_data_transfer.sh` | juicefs-s3-gateway request rate/totals (combined + per gateway) and consumer data transfer (per gateway); seaweedfs request rate/totals and data sent to juicefs |
| 28 | `28_resource_requests_limits_usage_cluster.sh` | CPU/memory requests, limits and usage, whole cluster - snapshot at window start + window average |
| 29 | `29_resource_requests_limits_usage_per_node.sh` | CPU/memory requests, limits and usage, per node - snapshot at window start + window average |
| 30 | `30_resource_requests_limits_usage_per_namespace.sh` | CPU/memory requests, limits and usage, per namespace - snapshot at window start + window average |
| 31 | `31_kueue_cpu_default_flavor_usage.sh` | Kueue `kleinkram-cluster-queue` / `cpu-default` flavor: resource usage vs. nominal quota (cpu+memory), admitted/pending workload counts - snapshot at window start + window average |
| 32 | `32_kueue_admitted_vs_waiting_timeseries.sh` | Kueue `kleinkram-cluster-queue`: admitted vs. pending (waiting) workload counts **over time** - a time series for plotting, not a single figure |

See the comment block at the top of each script for the exact PromQL and
the reasoning behind metric/unit choices (e.g. `container_memory_working_set_bytes`
over RSS, whole-node `node_cpu_seconds_total` over per-container sums for
the cluster-wide CPU figure).

### Caveat: node-to-node vs node-to-internet (scripts 09/10)

A node's physical NIC carries both cluster-internal and internet-bound
traffic indistinguishably at the node_exporter level, so the split is a
heuristic based on interface *name*, not actual destination.

Verified against this cluster's actual interfaces (K3s default
flannel/VXLAN): `flannel.1` is the overlay (the decapsulated view of
cross-node pod traffic) and goes in the node-to-node bucket; `cni0` and
the many `veth*@...` interfaces are **excluded from both buckets** because
they're the same pod packets viewed at an earlier hop (pod -> veth ->
cni0 -> flannel.1 -> wire) - counting them alongside `flannel.1` or the
physical NIC would double/triple-count the same bytes. The "external"
bucket is whatever's left on the real NIC(s) after excluding loopback/
bridge/veth, which is node-to-node-over-LAN traffic that isn't overlay
(control-plane calls, etc.) plus genuine internet egress - those two still
aren't separable from each other at this layer.

Both scripts also print the raw per-node/per-interface breakdown so you
can re-bucket by hand if your CNI uses different interface names than the
default `OVERLAY_REGEX`/`EXCLUDE_REGEX` assume.

### Caveat: node label mismatch between requests/limits and usage (script 29)

kube-state-metrics' `kube_pod_container_resource_requests`/`_limits` are
grouped by the `node` label (the Kubernetes node name), while usage falls
back to node_exporter's `instance` label (that target's host:port) - same
set of physical nodes, different label values. Cross-reference `kubectl
get nodes -o wide` if you need to line the two breakdowns up row-for-row.

### Script 32's output shape differs from every other script

32 is the one script in this folder that answers "how did this change
over time" rather than "what was this over the window", so it uses a new
`prom_query_range` helper (in `_lib.sh`) instead of `prom_query`. The
`results/*.json` it writes is `{"<labels>": [[timestamp, value], ...]}`
per series - feed that directly to a plotting script rather than reading
it as a single number. Resolution defaults to 30s (`RANGE_STEP` env var
to override), matching kube-prometheus-stack's default scrape interval.

### Caveat: scheduler metrics (script 18)

K3s runs the scheduler embedded in the k3s binary, and its metrics
endpoint is sometimes bound to localhost only, unreachable by kube-
prometheus-stack's `kubeScheduler` ServiceMonitor from off-node. If 18
comes back empty, check that target's health in Prometheus first before
assuming the cluster has zero scheduling latency.

## Suggested additional metrics for the paper

Not implemented yet - ask if you want a script for this:

- **Loki ingestion rate / chunk size**, if log volume during the window is
  worth reporting alongside the metrics volume.

Once you have a non-idle run to compare against, every script here (01-22)
works unchanged against a different `WINDOW_START`/`WINDOW_END` - the same
commands give you the under-load numbers for free.
