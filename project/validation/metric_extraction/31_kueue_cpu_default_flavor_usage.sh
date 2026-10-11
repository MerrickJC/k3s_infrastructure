#!/usr/bin/env bash
# Kueue's view of the kleinkram-cluster-queue ClusterQueue's cpu-default
# ResourceFlavor: usage vs. nominal quota for both cpu and memory, a
# snapshot at the start of the window plus the average across it. Also
# pulls the ClusterQueue's admitted/pending workload counts at the same
# two points, as a scalar companion to 32's full time series of the same
# thing.
#
# Requires kueue's values.yaml managerConfig.metrics.enableClusterQueueResources
# (already set - see apps/kueue/values.yaml) for kueue_cluster_queue_resource_usage
# / kueue_cluster_queue_nominal_quota to exist at all; both carry a `flavor`
# label alongside `cluster_queue`/`resource`, which is what lets this script
# isolate cpu-default instead of the ClusterQueue's total across every flavor
# (see apps/kube-kleinkram/dashboards/kleinkram-platform-grafana-dashboard.yaml
# panel 303 for the all-flavor version).
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"
source ./_lib.sh

CLUSTER_QUEUE="kleinkram-cluster-queue"
FLAVOR="cpu-default"

USAGE_CPU="kueue_cluster_queue_resource_usage{cluster_queue=\"${CLUSTER_QUEUE}\",flavor=\"${FLAVOR}\",resource=\"cpu\"}"
USAGE_MEM="kueue_cluster_queue_resource_usage{cluster_queue=\"${CLUSTER_QUEUE}\",flavor=\"${FLAVOR}\",resource=\"memory\"}"
QUOTA_CPU="kueue_cluster_queue_nominal_quota{cluster_queue=\"${CLUSTER_QUEUE}\",flavor=\"${FLAVOR}\",resource=\"cpu\"}"
QUOTA_MEM="kueue_cluster_queue_nominal_quota{cluster_queue=\"${CLUSTER_QUEUE}\",flavor=\"${FLAVOR}\",resource=\"memory\"}"
ADMITTED="sum(kueue_admitted_active_workloads{cluster_queue=\"${CLUSTER_QUEUE}\"})"
PENDING="sum(kueue_pending_workloads{cluster_queue=\"${CLUSTER_QUEUE}\"})"

USAGE_CPU_AVG="avg_over_time((${USAGE_CPU})[${RANGE}:1m])"
USAGE_MEM_AVG="avg_over_time((${USAGE_MEM})[${RANGE}:1m])"
QUOTA_CPU_AVG="avg_over_time((${QUOTA_CPU})[${RANGE}:1m])"
QUOTA_MEM_AVG="avg_over_time((${QUOTA_MEM})[${RANGE}:1m])"
ADMITTED_AVG="avg_over_time((${ADMITTED})[${RANGE}:1m])"
PENDING_AVG="avg_over_time((${PENDING})[${RANGE}:1m])"

pf_start

echo "Query (cpu-default CPU usage, at window start): $USAGE_CPU" >&2
prom_query "$USAGE_CPU" "usage_cpu_start" "$START_EPOCH"
echo "Query (cpu-default CPU usage, window average): $USAGE_CPU_AVG" >&2
prom_query "$USAGE_CPU_AVG" "usage_cpu_avg"

echo "Query (cpu-default memory usage, at window start): $USAGE_MEM" >&2
prom_query "$USAGE_MEM" "usage_memory_start" "$START_EPOCH"
echo "Query (cpu-default memory usage, window average): $USAGE_MEM_AVG" >&2
prom_query "$USAGE_MEM_AVG" "usage_memory_avg"

echo "Query (cpu-default CPU nominal quota, at window start): $QUOTA_CPU" >&2
prom_query "$QUOTA_CPU" "quota_cpu_start" "$START_EPOCH"
echo "Query (cpu-default CPU nominal quota, window average): $QUOTA_CPU_AVG" >&2
prom_query "$QUOTA_CPU_AVG" "quota_cpu_avg"

echo "Query (cpu-default memory nominal quota, at window start): $QUOTA_MEM" >&2
prom_query "$QUOTA_MEM" "quota_memory_start" "$START_EPOCH"
echo "Query (cpu-default memory nominal quota, window average): $QUOTA_MEM_AVG" >&2
prom_query "$QUOTA_MEM_AVG" "quota_memory_avg"

echo "Query (admitted active workloads, at window start): $ADMITTED" >&2
prom_query "$ADMITTED" "admitted_start" "$START_EPOCH"
echo "Query (admitted active workloads, window average): $ADMITTED_AVG" >&2
prom_query "$ADMITTED_AVG" "admitted_avg"

echo "Query (pending workloads, at window start): $PENDING" >&2
prom_query "$PENDING" "pending_start" "$START_EPOCH"
echo "Query (pending workloads, window average): $PENDING_AVG" >&2
prom_query "$PENDING_AVG" "pending_avg"
