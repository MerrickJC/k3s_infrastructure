#!/usr/bin/env bash
# Highest 1-minute-average memory usage per pod during the idle window, in
# bytes, restricted to the kleinkram / kleinkram-actions / juicefs
# namespaces.
#
# Same source as 08_peak_1m_memory_usage_per_namespace.sh, just grouped by
# pod instead of collapsed to a namespace total. Edit NAMESPACE_REGEX below
# to add/remove namespaces.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"
source ./_lib.sh

NAMESPACE_REGEX='kleinkram|kleinkram-actions|juicefs'

EXPR="max_over_time(avg_over_time((sum by (namespace, pod) (container_memory_working_set_bytes{namespace=~\"${NAMESPACE_REGEX}\",container!=\"\",container!=\"POD\"}))[1m:30s])[${RANGE}:1m])"

pf_start
echo "Query: $EXPR" >&2
prom_query "$EXPR"
