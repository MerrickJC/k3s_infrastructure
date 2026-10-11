#!/usr/bin/env bash
# CPU/memory requests, limits and actual usage for the whole cluster: a
# snapshot at the start of the window plus the average across it.
#
# Requests/limits come from kube-state-metrics' kube_pod_container_resource_*
# (resource="cpu"|"memory") - these only move when pods are created/deleted,
# so "start" and "avg" mostly sanity-check each other, but a mismatch is a
# sign of pod churn mid-window. Usage reuses the exact whole-node queries
# from 01/02 (node_cpu_seconds_total / MemTotal-MemAvailable) so these
# numbers are directly comparable to those scripts' idle-baseline figures.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"
source ./_lib.sh

REQ_CPU="sum(kube_pod_container_resource_requests{resource=\"cpu\"})"
REQ_MEM="sum(kube_pod_container_resource_requests{resource=\"memory\"})"
LIM_CPU="sum(kube_pod_container_resource_limits{resource=\"cpu\"})"
LIM_MEM="sum(kube_pod_container_resource_limits{resource=\"memory\"})"
USE_CPU="sum(rate(node_cpu_seconds_total{mode!=\"idle\"}[1m]))"
USE_MEM="sum(node_memory_MemTotal_bytes) - sum(node_memory_MemAvailable_bytes)"

REQ_CPU_AVG="avg_over_time((${REQ_CPU})[${RANGE}:1m])"
REQ_MEM_AVG="avg_over_time((${REQ_MEM})[${RANGE}:1m])"
LIM_CPU_AVG="avg_over_time((${LIM_CPU})[${RANGE}:1m])"
LIM_MEM_AVG="avg_over_time((${LIM_MEM})[${RANGE}:1m])"
USE_CPU_AVG="avg_over_time((${USE_CPU})[${RANGE}:1m])"
USE_MEM_AVG="avg_over_time((${USE_MEM})[${RANGE}:1m])"

pf_start

echo "Query (CPU requests, at window start): $REQ_CPU" >&2
prom_query "$REQ_CPU" "requests_cpu_start" "$START_EPOCH"
echo "Query (CPU requests, window average): $REQ_CPU_AVG" >&2
prom_query "$REQ_CPU_AVG" "requests_cpu_avg"

echo "Query (memory requests, at window start): $REQ_MEM" >&2
prom_query "$REQ_MEM" "requests_memory_start" "$START_EPOCH"
echo "Query (memory requests, window average): $REQ_MEM_AVG" >&2
prom_query "$REQ_MEM_AVG" "requests_memory_avg"

echo "Query (CPU limits, at window start): $LIM_CPU" >&2
prom_query "$LIM_CPU" "limits_cpu_start" "$START_EPOCH"
echo "Query (CPU limits, window average): $LIM_CPU_AVG" >&2
prom_query "$LIM_CPU_AVG" "limits_cpu_avg"

echo "Query (memory limits, at window start): $LIM_MEM" >&2
prom_query "$LIM_MEM" "limits_memory_start" "$START_EPOCH"
echo "Query (memory limits, window average): $LIM_MEM_AVG" >&2
prom_query "$LIM_MEM_AVG" "limits_memory_avg"

echo "Query (CPU usage, at window start): $USE_CPU" >&2
prom_query "$USE_CPU" "usage_cpu_start" "$START_EPOCH"
echo "Query (CPU usage, window average): $USE_CPU_AVG" >&2
prom_query "$USE_CPU_AVG" "usage_cpu_avg"

echo "Query (memory usage, at window start): $USE_MEM" >&2
prom_query "$USE_MEM" "usage_memory_start" "$START_EPOCH"
echo "Query (memory usage, window average): $USE_MEM_AVG" >&2
prom_query "$USE_MEM_AVG" "usage_memory_avg"
