#!/usr/bin/env bash
# Highest 1-minute-average CPU usage per namespace during the idle window,
# in cores.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"
source ./_lib.sh

EXPR="max_over_time((sum by (namespace) (rate(container_cpu_usage_seconds_total{namespace!=\"\",container!=\"\",container!=\"POD\"}[1m])))[${RANGE}:1m])"

pf_start
echo "Query: $EXPR" >&2
prom_query "$EXPR"
