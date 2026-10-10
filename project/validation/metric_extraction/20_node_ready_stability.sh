#!/usr/bin/env bash
# Whether every node stayed Ready for the whole idle window, per node.
#
# ready_min: the minimum value seen (at 1-minute resolution) of
# "Ready condition == true" (kube_state_metrics exposes this as 1/0) - a
# value of 1 means the node never flipped away from Ready at that
# resolution; 0 means it did at some point.
# ready_changes: how many times the raw (unsampled) condition flipped
# value during the window - 0 means rock solid, >0 means flapping.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"
source ./_lib.sh

READY_MIN="min_over_time(kube_node_status_condition{condition=\"Ready\",status=\"true\"}[${RANGE}:1m])"
READY_CHANGES="changes(kube_node_status_condition{condition=\"Ready\",status=\"true\"}[${RANGE}])"

pf_start
echo "Query (min Ready value per node, 1 = always Ready): $READY_MIN" >&2
prom_query "$READY_MIN" "ready_min"
echo "Query (Ready condition flips per node): $READY_CHANGES" >&2
prom_query "$READY_CHANGES" "ready_changes"
