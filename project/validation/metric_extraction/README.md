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
query (09-12) save one file per query with a suffix (e.g.
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

See the comment block at the top of each script for the exact PromQL and
the reasoning behind metric/unit choices (e.g. `container_memory_working_set_bytes`
over RSS, whole-node `node_cpu_seconds_total` over per-container sums for
the cluster-wide CPU figure).

### Caveat: node-to-node vs node-to-internet (scripts 09/10)

A node's physical NIC carries both cluster-internal and internet-bound
traffic indistinguishably at the node_exporter level. Scripts 09/10
approximate the split by interface *name* (CNI overlay interfaces =
node-to-node, everything else = external) and also print the raw
per-node/per-interface breakdown so you can re-bucket by hand if your CNI
uses different interface names than the default regex assumes.

## Suggested additional metrics for the paper

Not implemented yet - ask if you want scripts for these:

- **Disk I/O** (`node_disk_read_bytes_total` / `write_bytes_total`, IOPS via
  `node_disk_reads_completed_total`) - relevant given PostgreSQL + SeaweedFS
  are the storage-heavy workloads here.
- **Persistent volume usage/capacity** (`kubelet_volume_stats_used_bytes` /
  `_capacity_bytes`) - storage headroom per PVC.
- **Pod restart / crash counts** (`kube_pod_container_status_restarts_total`)
  and **OOM kills** (`container_oom_events_total`) - stability during the
  benchmark, not just resource cost.
- **Pod startup / scheduling latency** (`kube_pod_start_time` vs creation
  timestamp, or `scheduler_e2e_scheduling_duration_seconds`) - relevant
  since you already instrumented scheduler scoring (`k3_scores.py`).
- **API server latency/error rate** (`apiserver_request_duration_seconds`,
  `apiserver_request_total{code=~"5.."}`) - control-plane health under load.
  node count and `kube_node_status_condition` -
  whether all nodes stayed `Ready` throughout the run.
- **Network errors/retransmits** (`node_network_transmit_errs_total`,
  `node_netstat_Tcp_RetransSegs`) - distinguishes "idle" from "idle but
  struggling."
- **Prometheus's own resource/storage footprint**
  (`prometheus_tsdb_*`, container_memory/cpu for the `observability`
  namespace itself) - lets you quantify the observability stack's own
  overhead separately from the workload it's measuring.
- **Loki ingestion rate / chunk size** if log volume during the window is
  worth reporting alongside the metrics volume.

Once you have a non-idle run to compare against, the same scripts with a
different `WINDOW_START`/`WINDOW_END` give you the under-load numbers for
free - worth keeping that in mind when picking which of the above to add.
