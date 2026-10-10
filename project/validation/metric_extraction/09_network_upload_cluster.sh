#!/usr/bin/env bash
# Total bytes transmitted (upload) by each node's physical/overlay network
# interfaces over the idle window, split into an approximate
# node-to-node (cluster overlay) vs node-to-internet (external) bucket.
#
# CAVEAT: a single physical NIC carries both cluster-internal and
# internet-bound traffic, so this split is a heuristic based on interface
# *name*, not actual destination. Verified against this cluster's actual
# K3s/flannel topology (`kubectl debug node/<node> -it --image=busybox --
# ip addr`):
#   enp0s31f6         physical NIC - carries everything that leaves the
#                     box: VXLAN-encapsulated pod-to-pod traffic AND real
#                     external/internet traffic, indistinguishable here.
#   flannel.1         VXLAN overlay interface - the *inner*, decapsulated
#                     view of cross-node pod traffic only.
#   cni0, veth*@...   local bridge + per-pod veth legs. These are NOT
#                     extra traffic - they're the same pod packets, viewed
#                     at a different hop on their way to flannel.1 (or to
#                     another pod on the same node, which never reaches a
#                     physical NIC at all). Summing cni0/veth* alongside
#                     flannel.1 or enp0s31f6 would double/triple-count the
#                     same bytes, so they're deliberately excluded from
#                     both buckets below (they still show up in the raw
#                     breakdown for transparency).
# So: OVERLAY_REGEX = the VXLAN/overlay interface only (flannel/vxlan/
# cali/tunl depending on CNI - NOT cni0), and EXCLUDE_REGEX drops
# loopback + the local bridge/veth legs from the "external" bucket, which
# is everything left over on the real NIC(s) - i.e. node-to-node-over-LAN
# traffic that isn't overlay (control plane calls, etc.) plus genuine
# internet egress, still not separable from each other at this layer.
# Re-run with the raw breakdown if your CNI uses different interface names
# and adjust both regexes to match.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"
source ./_lib.sh

OVERLAY_REGEX='flannel.*|vxlan.*|cali.*|tunl.*'
EXCLUDE_REGEX='lo|veth.*|cni.*|docker.*|br-.*'

echo "--- Raw breakdown by node + interface (bytes transmitted) ---" >&2
RAW="sum by (instance, device) (increase(node_network_transmit_bytes_total{device!=\"lo\"}[${RANGE}]))"

echo "--- Bucketed: node-to-node (overlay) vs node-to-internet (external) ---" >&2
OVERLAY="sum(increase(node_network_transmit_bytes_total{device=~\"${OVERLAY_REGEX}\"}[${RANGE}]))"
EXTERNAL="sum(increase(node_network_transmit_bytes_total{device!~\"${OVERLAY_REGEX}\",device!~\"${EXCLUDE_REGEX}\"}[${RANGE}]))"

pf_start
echo "Query (raw): $RAW" >&2
prom_query "$RAW" "raw"
echo "Query (overlay / node-to-node): $OVERLAY" >&2
prom_query "$OVERLAY" "overlay"
echo "Query (external / node-to-internet): $EXTERNAL" >&2
prom_query "$EXTERNAL" "external"
