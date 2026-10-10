#!/usr/bin/env bash
# Average memory usage per namespace over the idle window, in bytes.
#
# container_memory_working_set_bytes is what the kernel OOM-killer actually
# watches (RSS + reclaimable page cache it's still using), and is what
# Kubernetes' own "Namespace (Pods)" Grafana dashboard plots - using it here
# keeps this comparable to anything you eyeballed in Grafana already.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"
source ./_lib.sh

EXPR="avg_over_time((sum by (namespace) (container_memory_working_set_bytes{namespace!=\"\",container!=\"\",container!=\"POD\"}))[${RANGE}:1m])"

pf_start
echo "Query: $EXPR" >&2
prom_query "$EXPR"
