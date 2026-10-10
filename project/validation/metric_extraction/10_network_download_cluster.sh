#!/usr/bin/env bash
# Total bytes received (download) by each node's physical/overlay network
# interfaces over the idle window, split into an approximate
# node-to-node (cluster overlay) vs node-to-internet (external) bucket.
#
# See the CAVEAT in 09_network_upload_cluster.sh - same heuristic (and the
# same cni0/veth* double-counting fix) applies here.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"
source ./_lib.sh

OVERLAY_REGEX='flannel.*|vxlan.*|cali.*|tunl.*'
EXCLUDE_REGEX='lo|veth.*|cni.*|docker.*|br-.*'

echo "--- Raw breakdown by node + interface (bytes received) ---" >&2
RAW="sum by (instance, device) (increase(node_network_receive_bytes_total{device!=\"lo\"}[${RANGE}]))"

echo "--- Bucketed: node-to-node (overlay) vs node-to-internet (external) ---" >&2
OVERLAY="sum(increase(node_network_receive_bytes_total{device=~\"${OVERLAY_REGEX}\"}[${RANGE}]))"
EXTERNAL="sum(increase(node_network_receive_bytes_total{device!~\"${OVERLAY_REGEX}\",device!~\"${EXCLUDE_REGEX}\"}[${RANGE}]))"

pf_start
echo "Query (raw): $RAW" >&2
prom_query "$RAW" "raw"
echo "Query (overlay / node-to-node): $OVERLAY" >&2
prom_query "$OVERLAY" "overlay"
echo "Query (external / node-to-internet): $EXTERNAL" >&2
prom_query "$EXTERNAL" "external"
