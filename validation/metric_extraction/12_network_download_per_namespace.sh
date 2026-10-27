#!/usr/bin/env bash
# Total bytes received (download) per namespace over the idle window, plus
# the equivalent average throughput in bytes/sec for convenience.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"
source ./_lib.sh

TOTAL="sum by (namespace) (increase(container_network_receive_bytes_total{namespace!=\"\"}[${RANGE}]))"
RATE="sum by (namespace) (rate(container_network_receive_bytes_total{namespace!=\"\"}[${RANGE}]))"

pf_start
echo "Query (total bytes over window): $TOTAL" >&2
prom_query "$TOTAL" "total"
echo "Query (average bytes/sec over window): $RATE" >&2
prom_query "$RATE" "rate"
