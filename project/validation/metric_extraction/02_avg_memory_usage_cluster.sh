#!/usr/bin/env bash
# Average memory used across the entire cluster over the idle window, in bytes.
#
# node_memory_MemTotal_bytes - node_memory_MemAvailable_bytes = "used"
# (MemAvailable already accounts for reclaimable cache/buffers, so this is
# the standard "actually in use" figure, not the misleading MemFree).
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"
source ./_lib.sh

EXPR="avg_over_time((sum(node_memory_MemTotal_bytes) - sum(node_memory_MemAvailable_bytes))[${RANGE}:1m])"

pf_start
echo "Query: $EXPR" >&2
prom_query "$EXPR"
