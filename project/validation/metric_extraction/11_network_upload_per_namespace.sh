#!/usr/bin/env bash
# Total bytes transmitted (upload) per namespace over the idle window, plus
# the equivalent average throughput in bytes/sec for convenience.
#
# container_network_transmit_bytes_total is reported by cAdvisor once per
# pod network namespace (not per-container), so summing by namespace alone
# (no container filter) is correct and does not double-count.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"
source ./_lib.sh

TOTAL="sum by (namespace) (increase(container_network_transmit_bytes_total{namespace!=\"\"}[${RANGE}]))"
RATE="sum by (namespace) (rate(container_network_transmit_bytes_total{namespace!=\"\"}[${RANGE}]))"

pf_start
echo "Query (total bytes over window): $TOTAL" >&2
prom_query "$TOTAL" "total"
echo "Query (average bytes/sec over window): $RATE" >&2
prom_query "$RATE" "rate"
