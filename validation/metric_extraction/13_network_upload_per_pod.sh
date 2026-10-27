#!/usr/bin/env bash
# Total bytes transmitted (upload) per pod over the idle window, labelled
# with the node the pod was running on.
#
# kube_pod_info (from kube-state-metrics) carries the `node` label; it's
# joined on (namespace,pod) via group_left since container_network_* has no
# node label of its own.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"
source ./_lib.sh

EXPR="sum by (namespace, pod, node) (increase(container_network_transmit_bytes_total{namespace!=\"\"}[${RANGE}]) * on(namespace, pod) group_left(node) kube_pod_info)"

pf_start
echo "Query: $EXPR" >&2
prom_query "$EXPR"
