#!/usr/bin/env bash
# CPU/memory requests, limits and actual usage per namespace: a snapshot
# at the start of the window plus the average across it.
#
# Usage reuses the exact per-namespace queries from 03/04
# (container_cpu_usage_seconds_total / container_memory_working_set_bytes,
# container!="POD" dropping pause containers) so these numbers are
# directly comparable to those scripts' idle-baseline figures.
# Requests/limits come from kube-state-metrics' kube_pod_container_resource_*
# (resource="cpu"|"memory") - these only move when pods are created/deleted,
# so "start" and "avg" mostly sanity-check each other.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"
source ./_lib.sh

REQ_CPU="sum by (namespace) (kube_pod_container_resource_requests{namespace!=\"\",resource=\"cpu\"})"
REQ_MEM="sum by (namespace) (kube_pod_container_resource_requests{namespace!=\"\",resource=\"memory\"})"
LIM_CPU="sum by (namespace) (kube_pod_container_resource_limits{namespace!=\"\",resource=\"cpu\"})"
LIM_MEM="sum by (namespace) (kube_pod_container_resource_limits{namespace!=\"\",resource=\"memory\"})"
USE_CPU="sum by (namespace) (rate(container_cpu_usage_seconds_total{namespace!=\"\",container!=\"\",container!=\"POD\"}[1m]))"
USE_MEM="sum by (namespace) (container_memory_working_set_bytes{namespace!=\"\",container!=\"\",container!=\"POD\"})"

REQ_CPU_AVG="avg_over_time((${REQ_CPU})[${RANGE}:1m])"
REQ_MEM_AVG="avg_over_time((${REQ_MEM})[${RANGE}:1m])"
LIM_CPU_AVG="avg_over_time((${LIM_CPU})[${RANGE}:1m])"
LIM_MEM_AVG="avg_over_time((${LIM_MEM})[${RANGE}:1m])"
USE_CPU_AVG="avg_over_time((${USE_CPU})[${RANGE}:1m])"
USE_MEM_AVG="avg_over_time((${USE_MEM})[${RANGE}:1m])"

pf_start

echo "Query (CPU requests per namespace, at window start): $REQ_CPU" >&2
prom_query "$REQ_CPU" "requests_cpu_start" "$START_EPOCH"
echo "Query (CPU requests per namespace, window average): $REQ_CPU_AVG" >&2
prom_query "$REQ_CPU_AVG" "requests_cpu_avg"

echo "Query (memory requests per namespace, at window start): $REQ_MEM" >&2
prom_query "$REQ_MEM" "requests_memory_start" "$START_EPOCH"
echo "Query (memory requests per namespace, window average): $REQ_MEM_AVG" >&2
prom_query "$REQ_MEM_AVG" "requests_memory_avg"

echo "Query (CPU limits per namespace, at window start): $LIM_CPU" >&2
prom_query "$LIM_CPU" "limits_cpu_start" "$START_EPOCH"
echo "Query (CPU limits per namespace, window average): $LIM_CPU_AVG" >&2
prom_query "$LIM_CPU_AVG" "limits_cpu_avg"

echo "Query (memory limits per namespace, at window start): $LIM_MEM" >&2
prom_query "$LIM_MEM" "limits_memory_start" "$START_EPOCH"
echo "Query (memory limits per namespace, window average): $LIM_MEM_AVG" >&2
prom_query "$LIM_MEM_AVG" "limits_memory_avg"

echo "Query (CPU usage per namespace, at window start): $USE_CPU" >&2
prom_query "$USE_CPU" "usage_cpu_start" "$START_EPOCH"
echo "Query (CPU usage per namespace, window average): $USE_CPU_AVG" >&2
prom_query "$USE_CPU_AVG" "usage_cpu_avg"

echo "Query (memory usage per namespace, at window start): $USE_MEM" >&2
prom_query "$USE_MEM" "usage_memory_start" "$START_EPOCH"
echo "Query (memory usage per namespace, window average): $USE_MEM_AVG" >&2
prom_query "$USE_MEM_AVG" "usage_memory_avg"
