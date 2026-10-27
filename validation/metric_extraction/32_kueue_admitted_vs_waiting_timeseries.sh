#!/usr/bin/env bash
# Admitted vs. waiting (pending) workloads over time for the
# kleinkram-cluster-queue ClusterQueue - a time series, not a single
# number, so it can be plotted directly (x = time, y = workload count,
# one line per series below) rather than read as a scalar like every
# other script in this folder.
#
# kueue_admitted_active_workloads and kueue_pending_workloads are gauges
# kept per cluster_queue (not per flavor - admission happens at the
# ClusterQueue level), so this isn't filtered to cpu-default specifically;
# see 31 for the cpu-default flavor's usage-vs-quota numbers. pending is
# also broken out by `status` (kueue's own split of why a workload is
# waiting) in case the combined line hides something interesting.
#
# Uses prom_query_range (see _lib.sh) instead of prom_query - every other
# script in this folder wants one number for the whole window, this one
# wants the whole window.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"
source ./_lib.sh

CLUSTER_QUEUE="kleinkram-cluster-queue"

ADMITTED="sum(kueue_admitted_active_workloads{cluster_queue=\"${CLUSTER_QUEUE}\"})"
PENDING="sum(kueue_pending_workloads{cluster_queue=\"${CLUSTER_QUEUE}\"})"
PENDING_BY_STATUS="sum by (status) (kueue_pending_workloads{cluster_queue=\"${CLUSTER_QUEUE}\"})"

pf_start

echo "Query (admitted active workloads over time): $ADMITTED" >&2
prom_query_range "$ADMITTED" "admitted"

echo "Query (pending workloads over time): $PENDING" >&2
prom_query_range "$PENDING" "pending"

echo "Query (pending workloads over time, by status): $PENDING_BY_STATUS" >&2
prom_query_range "$PENDING_BY_STATUS" "pending_by_status"
