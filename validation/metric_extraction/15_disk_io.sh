#!/usr/bin/env bash
# Disk I/O across the cluster over the idle window: total bytes read/
# written, average throughput (bytes/sec), and average IOPS - both
# cluster-wide and broken down per node (by the `instance` label, same
# convention as the per-node breakdown in 09/10).
#
# Relevant because PostgreSQL and SeaweedFS are the storage-heavy
# workloads here - this quantifies their disk footprint even at idle
# (WAL checkpoints, compaction, etc. still happen with no app traffic).
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"
source ./_lib.sh

READ_BYTES_TOTAL="sum(increase(node_disk_read_bytes_total[${RANGE}]))"
READ_BYTES_RATE="sum(rate(node_disk_read_bytes_total[${RANGE}]))"
WRITE_BYTES_TOTAL="sum(increase(node_disk_written_bytes_total[${RANGE}]))"
WRITE_BYTES_RATE="sum(rate(node_disk_written_bytes_total[${RANGE}]))"
READ_IOPS_RATE="sum(rate(node_disk_reads_completed_total[${RANGE}]))"
WRITE_IOPS_RATE="sum(rate(node_disk_writes_completed_total[${RANGE}]))"

READ_BYTES_TOTAL_PER_NODE="sum by (instance) (increase(node_disk_read_bytes_total[${RANGE}]))"
READ_BYTES_RATE_PER_NODE="sum by (instance) (rate(node_disk_read_bytes_total[${RANGE}]))"
WRITE_BYTES_TOTAL_PER_NODE="sum by (instance) (increase(node_disk_written_bytes_total[${RANGE}]))"
WRITE_BYTES_RATE_PER_NODE="sum by (instance) (rate(node_disk_written_bytes_total[${RANGE}]))"
READ_IOPS_RATE_PER_NODE="sum by (instance) (rate(node_disk_reads_completed_total[${RANGE}]))"
WRITE_IOPS_RATE_PER_NODE="sum by (instance) (rate(node_disk_writes_completed_total[${RANGE}]))"

pf_start
echo "Query (read bytes total): $READ_BYTES_TOTAL" >&2
prom_query "$READ_BYTES_TOTAL" "read_bytes_total"
echo "Query (read bytes/sec avg): $READ_BYTES_RATE" >&2
prom_query "$READ_BYTES_RATE" "read_bytes_rate"
echo "Query (write bytes total): $WRITE_BYTES_TOTAL" >&2
prom_query "$WRITE_BYTES_TOTAL" "write_bytes_total"
echo "Query (write bytes/sec avg): $WRITE_BYTES_RATE" >&2
prom_query "$WRITE_BYTES_RATE" "write_bytes_rate"
echo "Query (read IOPS avg): $READ_IOPS_RATE" >&2
prom_query "$READ_IOPS_RATE" "read_iops"
echo "Query (write IOPS avg): $WRITE_IOPS_RATE" >&2
prom_query "$WRITE_IOPS_RATE" "write_iops"

echo "--- Per-node breakdown ---" >&2
echo "Query (read bytes total, per node): $READ_BYTES_TOTAL_PER_NODE" >&2
prom_query "$READ_BYTES_TOTAL_PER_NODE" "read_bytes_total_per_node"
echo "Query (read bytes/sec avg, per node): $READ_BYTES_RATE_PER_NODE" >&2
prom_query "$READ_BYTES_RATE_PER_NODE" "read_bytes_rate_per_node"
echo "Query (write bytes total, per node): $WRITE_BYTES_TOTAL_PER_NODE" >&2
prom_query "$WRITE_BYTES_TOTAL_PER_NODE" "write_bytes_total_per_node"
echo "Query (write bytes/sec avg, per node): $WRITE_BYTES_RATE_PER_NODE" >&2
prom_query "$WRITE_BYTES_RATE_PER_NODE" "write_bytes_rate_per_node"
echo "Query (read IOPS avg, per node): $READ_IOPS_RATE_PER_NODE" >&2
prom_query "$READ_IOPS_RATE_PER_NODE" "read_iops_per_node"
echo "Query (write IOPS avg, per node): $WRITE_IOPS_RATE_PER_NODE" >&2
prom_query "$WRITE_IOPS_RATE_PER_NODE" "write_iops_per_node"
