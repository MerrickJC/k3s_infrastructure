#!/usr/bin/env bash
# Average CPU usage per pod over the idle window, in cores, restricted to
# the kleinkram / kleinkram-actions / juicefs namespaces.
#
# Same container_cpu_usage_seconds_total source as
# 03_avg_cpu_usage_per_namespace.sh, just grouped by pod instead of
# collapsed to a namespace total. Edit NAMESPACE_REGEX below to add/remove
# namespaces.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"
source ./_lib.sh

NAMESPACE_REGEX='kleinkram|kleinkram-actions|juicefs'

EXPR="avg_over_time((sum by (namespace, pod) (rate(container_cpu_usage_seconds_total{namespace=~\"${NAMESPACE_REGEX}\",container!=\"\",container!=\"POD\"}[1m])))[${RANGE}:1m])"

pf_start
echo "Query: $EXPR" >&2
prom_query "$EXPR"
