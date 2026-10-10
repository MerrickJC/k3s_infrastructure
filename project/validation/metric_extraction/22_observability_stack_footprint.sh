#!/usr/bin/env bash
# Resource cost of the observability stack itself (Prometheus, Grafana,
# Loki, Alertmanager, exporters - everything in the `observability`
# namespace), plus a few Prometheus-specific internals. Lets you separate
# "what the platform being benchmarked costs" from "what measuring it
# costs" when reporting the idle-baseline figures from scripts 01-04.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"
source ./_lib.sh

CPU="avg_over_time((sum(rate(container_cpu_usage_seconds_total{namespace=\"observability\",container!=\"\",container!=\"POD\"}[1m])))[${RANGE}:1m])"
MEMORY="avg_over_time((sum(container_memory_working_set_bytes{namespace=\"observability\",container!=\"\",container!=\"POD\"}))[${RANGE}:1m])"
HEAD_SERIES="sum(prometheus_tsdb_head_series)"
STORAGE_BYTES="sum(prometheus_tsdb_storage_blocks_bytes)"
INGEST_RATE="sum(rate(prometheus_tsdb_head_samples_appended_total[${RANGE}]))"

pf_start
echo "Query (observability namespace CPU, cores): $CPU" >&2
prom_query "$CPU" "cpu_cores"
echo "Query (observability namespace memory, bytes): $MEMORY" >&2
prom_query "$MEMORY" "memory_bytes"
echo "Query (Prometheus head series count, snapshot): $HEAD_SERIES" >&2
prom_query "$HEAD_SERIES" "prometheus_head_series"
echo "Query (Prometheus on-disk block bytes, snapshot): $STORAGE_BYTES" >&2
prom_query "$STORAGE_BYTES" "prometheus_storage_bytes"
echo "Query (Prometheus samples ingested/sec, avg): $INGEST_RATE" >&2
prom_query "$INGEST_RATE" "prometheus_ingest_rate"
