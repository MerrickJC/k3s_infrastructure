#!/usr/bin/env bash
# Highest 1-minute-average memory usage across the entire cluster during the
# idle window, in bytes.
#
# Memory is a gauge, not a counter, so "1-minute average" is a literal
# rolling average of samples (inner avg_over_time), and the outer
# max_over_time finds the worst such minute in the window.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"
source ./_lib.sh

EXPR="max_over_time(avg_over_time((sum(node_memory_MemTotal_bytes) - sum(node_memory_MemAvailable_bytes))[1m:30s])[${RANGE}:1m])"

pf_start
echo "Query: $EXPR" >&2
prom_query "$EXPR"
