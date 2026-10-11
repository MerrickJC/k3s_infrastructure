#!/usr/bin/env bash
# CPU/memory requests, limits and actual usage per node: a snapshot at the
# start of the window plus the average across it.
#
# Caveat: requests/limits are grouped by kube-state-metrics' `node` label
# (the Kubernetes node name), while usage is grouped by node_exporter's
# `instance` label (host:port of its metrics endpoint) - same physical
# nodes, different label values, so don't expect the two breakdowns to
# line up key-for-key without cross-referencing `kubectl get nodes -o wide`.
# Usage itself is whole-node (node_cpu_seconds_total / MemTotal-
# MemAvailable), same source as 01/02/28, just grouped instead of summed.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"
source ./_lib.sh

REQ_CPU="sum by (node) (kube_pod_container_resource_requests{resource=\"cpu\"})"
REQ_MEM="sum by (node) (kube_pod_container_resource_requests{resource=\"memory\"})"
LIM_CPU="sum by (node) (kube_pod_container_resource_limits{resource=\"cpu\"})"
LIM_MEM="sum by (node) (kube_pod_container_resource_limits{resource=\"memory\"})"
USE_CPU="sum by (instance) (rate(node_cpu_seconds_total{mode!=\"idle\"}[1m]))"
USE_MEM="sum by (instance) (node_memory_MemTotal_bytes - node_memory_MemAvailable_bytes)"

REQ_CPU_AVG="avg_over_time((${REQ_CPU})[${RANGE}:1m])"
REQ_MEM_AVG="avg_over_time((${REQ_MEM})[${RANGE}:1m])"
LIM_CPU_AVG="avg_over_time((${LIM_CPU})[${RANGE}:1m])"
LIM_MEM_AVG="avg_over_time((${LIM_MEM})[${RANGE}:1m])"
USE_CPU_AVG="avg_over_time((${USE_CPU})[${RANGE}:1m])"
USE_MEM_AVG="avg_over_time((${USE_MEM})[${RANGE}:1m])"

pf_start

echo "Query (CPU requests per node, at window start): $REQ_CPU" >&2
prom_query "$REQ_CPU" "requests_cpu_start" "$START_EPOCH"
echo "Query (CPU requests per node, window average): $REQ_CPU_AVG" >&2
prom_query "$REQ_CPU_AVG" "requests_cpu_avg"

echo "Query (memory requests per node, at window start): $REQ_MEM" >&2
prom_query "$REQ_MEM" "requests_memory_start" "$START_EPOCH"
echo "Query (memory requests per node, window average): $REQ_MEM_AVG" >&2
prom_query "$REQ_MEM_AVG" "requests_memory_avg"

echo "Query (CPU limits per node, at window start): $LIM_CPU" >&2
prom_query "$LIM_CPU" "limits_cpu_start" "$START_EPOCH"
echo "Query (CPU limits per node, window average): $LIM_CPU_AVG" >&2
prom_query "$LIM_CPU_AVG" "limits_cpu_avg"

echo "Query (memory limits per node, at window start): $LIM_MEM" >&2
prom_query "$LIM_MEM" "limits_memory_start" "$START_EPOCH"
echo "Query (memory limits per node, window average): $LIM_MEM_AVG" >&2
prom_query "$LIM_MEM_AVG" "limits_memory_avg"

echo "Query (CPU usage per node, at window start): $USE_CPU" >&2
prom_query "$USE_CPU" "usage_cpu_start" "$START_EPOCH"
echo "Query (CPU usage per node, window average): $USE_CPU_AVG" >&2
prom_query "$USE_CPU_AVG" "usage_cpu_avg"

echo "Query (memory usage per node, at window start): $USE_MEM" >&2
prom_query "$USE_MEM" "usage_memory_start" "$START_EPOCH"
echo "Query (memory usage per node, window average): $USE_MEM_AVG" >&2
prom_query "$USE_MEM_AVG" "usage_memory_avg"
