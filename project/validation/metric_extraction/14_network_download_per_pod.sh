#!/usr/bin/env bash
# Total bytes received (download) per pod over the idle window, labelled
# with the node the pod was running on.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"
source ./_lib.sh

EXPR="sum by (namespace, pod, node) (increase(container_network_receive_bytes_total{namespace!=\"\"}[${RANGE}]) * on(namespace, pod) group_left(node) kube_pod_info)"

pf_start
echo "Query: $EXPR" >&2
prom_query "$EXPR"
