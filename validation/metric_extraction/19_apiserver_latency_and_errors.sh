#!/usr/bin/env bash
# Kubernetes API server request latency (average + p99) and server-error
# rate over the idle window - control-plane health, independent of your
# own workload's resource usage.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"
source ./_lib.sh

AVG_LATENCY="sum(increase(apiserver_request_duration_seconds_sum[${RANGE}])) / sum(increase(apiserver_request_duration_seconds_count[${RANGE}]))"
P99_LATENCY="histogram_quantile(0.99, sum(rate(apiserver_request_duration_seconds_bucket[${RANGE}])) by (le))"
TOTAL_REQUESTS="sum(increase(apiserver_request_total[${RANGE}]))"
ERROR_REQUESTS="sum(increase(apiserver_request_total{code=~\"5..\"}[${RANGE}]))"

pf_start
echo "Query (average latency, seconds): $AVG_LATENCY" >&2
prom_query "$AVG_LATENCY" "avg_latency_seconds"
echo "Query (p99 latency, seconds): $P99_LATENCY" >&2
prom_query "$P99_LATENCY" "p99_latency_seconds"
echo "Query (total requests): $TOTAL_REQUESTS" >&2
prom_query "$TOTAL_REQUESTS" "total_requests"
echo "Query (5xx error requests): $ERROR_REQUESTS" >&2
prom_query "$ERROR_REQUESTS" "error_requests"
