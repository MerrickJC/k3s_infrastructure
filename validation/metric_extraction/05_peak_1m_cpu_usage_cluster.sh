#!/usr/bin/env bash
# Highest 1-minute-average CPU usage across the entire cluster during the
# idle window, in cores (i.e. max over the window of a sliding 1m rate).
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"
source ./_lib.sh

EXPR="max_over_time((sum(rate(node_cpu_seconds_total{mode!=\"idle\"}[1m])))[${RANGE}:1m])"

pf_start
echo "Query: $EXPR" >&2
prom_query "$EXPR"
