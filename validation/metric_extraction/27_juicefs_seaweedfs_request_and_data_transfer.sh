#!/usr/bin/env bash
# S3-layer request volume and data transfer over the idle window, for the
# two object-storage hops in the stack: consumers (kleinkram etc.) <->
# juicefs-s3-gateway <-> seaweedfs.
#
# Metric sources (see apps/juicefs-s3-gateway/observability.yaml and
# apps/seaweedfs/values.yaml's global.seaweedfs.monitoring.enabled for how
# each gets scraped):
#
#   juicefs_sdk_ops_durations_histogram_seconds_count
#     Histogram emitted by each gateway pod (one per node, DaemonSet) for
#     every S3 API call it serves - the gateway translates each incoming
#     S3 request into a JuiceFS SDK op, so this histogram's _count is the
#     best available proxy for "requests made to the juicefs s3 gateway".
#     Grouped by the `node` label the ServiceMonitor relabeling stamps on
#     (one series per gateway instance).
#
#   juicefs_sdk_read_size_bytes_sum / juicefs_sdk_written_size_bytes_sum
#     Histograms of SDK read/write request sizes. From the gateway's point
#     of view, a "read" is data it sends back to a consumer (download) and
#     a "write" is data a consumer sends it (upload) - so _sum on each
#     gives total bytes transferred-to / received-from consumers per
#     gateway.
#
#   SeaweedFS_s3_request_total
#     Counter on the SeaweedFS S3 component itself (labelled type/code/
#     bucket - `type` is the S3 operation), i.e. requests SeaweedFS
#     actually received - used here instead of juicefs_object_request_*
#     so "requests made to seaweedfs" is measured from seaweedfs's own
#     side rather than inferred from the client.
#
#   SeaweedFS_s3_bucket_traffic_sent_bytes_total
#     Counter of bytes SeaweedFS's S3 component has sent out, labelled
#     bucket. seaweedfs serves 4 buckets (zot-registry, argo-workflows,
#     juicefs, postgres-backups - see createBuckets in
#     apps/seaweedfs/values.yaml), each with a different sole consumer, so
#     the seaweedfs-to-juicefs transfer query below is scoped to
#     bucket="juicefs" specifically - juicefs is only the sole reader of
#     that one bucket, not of seaweedfs as a whole. The per-bucket
#     breakdown query still reports all 4 for context.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"
source ./_lib.sh

# --- juicefs-s3-gateway: requests received from consumers ---
JFS_REQ_TOTAL="sum(increase(juicefs_sdk_ops_durations_histogram_seconds_count{namespace=\"juicefs\"}[${RANGE}]))"
JFS_REQ_RATE="sum(rate(juicefs_sdk_ops_durations_histogram_seconds_count{namespace=\"juicefs\"}[${RANGE}]))"
JFS_REQ_TOTAL_PER_GATEWAY="sum by (node) (increase(juicefs_sdk_ops_durations_histogram_seconds_count{namespace=\"juicefs\"}[${RANGE}]))"
JFS_REQ_RATE_PER_GATEWAY="sum by (node) (rate(juicefs_sdk_ops_durations_histogram_seconds_count{namespace=\"juicefs\"}[${RANGE}]))"

# --- juicefs-s3-gateway: data to/from consumers, per gateway + combined ---
JFS_RECEIVED_FROM_CONSUMERS_TOTAL="sum(increase(juicefs_sdk_written_size_bytes_sum{namespace=\"juicefs\"}[${RANGE}]))"
JFS_RECEIVED_FROM_CONSUMERS_PER_GATEWAY="sum by (node) (increase(juicefs_sdk_written_size_bytes_sum{namespace=\"juicefs\"}[${RANGE}]))"
JFS_TRANSFERRED_TO_CONSUMERS_TOTAL="sum(increase(juicefs_sdk_read_size_bytes_sum{namespace=\"juicefs\"}[${RANGE}]))"
JFS_TRANSFERRED_TO_CONSUMERS_PER_GATEWAY="sum by (node) (increase(juicefs_sdk_read_size_bytes_sum{namespace=\"juicefs\"}[${RANGE}]))"

# --- seaweedfs: requests received (from juicefs) ---
SWFS_REQ_TOTAL="sum(increase(SeaweedFS_s3_request_total[${RANGE}]))"
SWFS_REQ_RATE="sum(rate(SeaweedFS_s3_request_total[${RANGE}]))"
SWFS_REQ_TOTAL_PER_ACTION="sum by (type) (increase(SeaweedFS_s3_request_total[${RANGE}]))"

# --- seaweedfs -> juicefs data transfer ---
# Scoped to bucket="juicefs" - that's the only bucket juicefs is the sole
# reader of (zot-registry/argo-workflows/postgres-backups have other
# consumers, so summing across all buckets would overcount).
SWFS_TO_JFS_BYTES_TOTAL="sum(increase(SeaweedFS_s3_bucket_traffic_sent_bytes_total{bucket=\"juicefs\"}[${RANGE}]))"
SWFS_TO_JFS_BYTES_PER_BUCKET="sum by (bucket) (increase(SeaweedFS_s3_bucket_traffic_sent_bytes_total[${RANGE}]))"

pf_start

echo "--- juicefs-s3-gateway: request volume ---" >&2
echo "Query (total requests, combined): $JFS_REQ_TOTAL" >&2
prom_query "$JFS_REQ_TOTAL" "jfs_requests_total"
echo "Query (avg requests/sec, combined): $JFS_REQ_RATE" >&2
prom_query "$JFS_REQ_RATE" "jfs_requests_rate_combined"
echo "Query (total requests, per gateway): $JFS_REQ_TOTAL_PER_GATEWAY" >&2
prom_query "$JFS_REQ_TOTAL_PER_GATEWAY" "jfs_requests_total_per_gateway"
echo "Query (avg requests/sec, per gateway): $JFS_REQ_RATE_PER_GATEWAY" >&2
prom_query "$JFS_REQ_RATE_PER_GATEWAY" "jfs_requests_rate_per_gateway"

echo "--- juicefs-s3-gateway: data to/from consumers ---" >&2
echo "Query (total bytes received from consumers, combined): $JFS_RECEIVED_FROM_CONSUMERS_TOTAL" >&2
prom_query "$JFS_RECEIVED_FROM_CONSUMERS_TOTAL" "jfs_received_from_consumers_total"
echo "Query (total bytes received from consumers, per gateway): $JFS_RECEIVED_FROM_CONSUMERS_PER_GATEWAY" >&2
prom_query "$JFS_RECEIVED_FROM_CONSUMERS_PER_GATEWAY" "jfs_received_from_consumers_per_gateway"
echo "Query (total bytes transferred to consumers, combined): $JFS_TRANSFERRED_TO_CONSUMERS_TOTAL" >&2
prom_query "$JFS_TRANSFERRED_TO_CONSUMERS_TOTAL" "jfs_transferred_to_consumers_total"
echo "Query (total bytes transferred to consumers, per gateway): $JFS_TRANSFERRED_TO_CONSUMERS_PER_GATEWAY" >&2
prom_query "$JFS_TRANSFERRED_TO_CONSUMERS_PER_GATEWAY" "jfs_transferred_to_consumers_per_gateway"

echo "--- seaweedfs: request volume ---" >&2
echo "Query (total requests): $SWFS_REQ_TOTAL" >&2
prom_query "$SWFS_REQ_TOTAL" "seaweedfs_requests_total"
echo "Query (avg requests/sec): $SWFS_REQ_RATE" >&2
prom_query "$SWFS_REQ_RATE" "seaweedfs_requests_rate"
echo "Query (total requests, per S3 action - raw breakdown): $SWFS_REQ_TOTAL_PER_ACTION" >&2
prom_query "$SWFS_REQ_TOTAL_PER_ACTION" "seaweedfs_requests_total_per_action"

echo "--- seaweedfs -> juicefs data transfer ---" >&2
echo "Query (total bytes, juicefs bucket only - juicefs is its sole reader): $SWFS_TO_JFS_BYTES_TOTAL" >&2
prom_query "$SWFS_TO_JFS_BYTES_TOTAL" "seaweedfs_to_juicefs_bytes_total"
echo "Query (total bytes, per bucket - raw breakdown): $SWFS_TO_JFS_BYTES_PER_BUCKET" >&2
prom_query "$SWFS_TO_JFS_BYTES_PER_BUCKET" "seaweedfs_to_juicefs_bytes_per_bucket"
