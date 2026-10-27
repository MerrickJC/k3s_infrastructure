#!/usr/bin/env bash
# Average CPU usage per namespace over the idle window, in cores.
#
# container_cpu_usage_seconds_total comes from cAdvisor via the kubelet
# ServiceMonitor. container!="" / !="POD" drops the cgroup-summary and
# pause-container series so each real container is counted exactly once.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"
source ./_lib.sh

EXPR="avg_over_time((sum by (namespace) (rate(container_cpu_usage_seconds_total{namespace!=\"\",container!=\"\",container!=\"POD\"}[1m])))[${RANGE}:1m])"

pf_start
echo "Query: $EXPR" >&2
prom_query "$EXPR"
