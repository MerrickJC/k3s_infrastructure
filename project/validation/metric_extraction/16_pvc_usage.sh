#!/usr/bin/env bash
# PersistentVolumeClaim usage and capacity, per namespace+claim, averaged
# over the idle window (bytes). Shows storage headroom for every PVC-backed
# volume (PostgreSQL, SeaweedFS, Prometheus/Grafana/Loki's own storage...).
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"
source ./_lib.sh

USED="avg_over_time(kubelet_volume_stats_used_bytes[${RANGE}:1m])"
CAPACITY="avg_over_time(kubelet_volume_stats_capacity_bytes[${RANGE}:1m])"

pf_start
echo "Query (used bytes): $USED" >&2
prom_query "$USED" "used_bytes"
echo "Query (capacity bytes): $CAPACITY" >&2
prom_query "$CAPACITY" "capacity_bytes"
