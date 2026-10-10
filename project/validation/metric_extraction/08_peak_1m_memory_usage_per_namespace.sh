#!/usr/bin/env bash
# Highest 1-minute-average memory usage per namespace during the idle
# window, in bytes.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"
source ./_lib.sh

EXPR="max_over_time(avg_over_time((sum by (namespace) (container_memory_working_set_bytes{namespace!=\"\",container!=\"\",container!=\"POD\"}))[1m:30s])[${RANGE}:1m])"

pf_start
echo "Query: $EXPR" >&2
prom_query "$EXPR"
