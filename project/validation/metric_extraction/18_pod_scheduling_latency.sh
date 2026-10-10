#!/usr/bin/env bash
# Average and p99 pod scheduling latency over the idle window, from the
# kube-scheduler's own histogram (time from "pod became schedulable" to
# "scheduler picked a node" - does not include image pull / container
# start, just the scheduling decision itself).
#
# CAVEAT: on K3s the scheduler runs embedded in the k3s binary and its
# metrics endpoint is sometimes bound to localhost only, which kube-
# prometheus-stack's kubeScheduler ServiceMonitor target can't reach from
# off-node - if these queries come back empty, that's almost certainly why
# (check the "kube-scheduler" target's health, e.g. in Prometheus's
# /targets page via `kubectl port-forward` to this same service).
#
# scheduler_scheduling_attempt_duration_seconds is the current metric name
# (k8s 1.19+); older clusters may need scheduler_e2e_scheduling_duration_seconds
# instead.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"
source ./_lib.sh

AVG="sum(increase(scheduler_scheduling_attempt_duration_seconds_sum[${RANGE}])) / sum(increase(scheduler_scheduling_attempt_duration_seconds_count[${RANGE}]))"
P99="histogram_quantile(0.99, sum(rate(scheduler_scheduling_attempt_duration_seconds_bucket[${RANGE}])) by (le))"

pf_start
echo "Query (average latency, seconds): $AVG" >&2
prom_query "$AVG" "avg_seconds"
echo "Query (p99 latency, seconds): $P99" >&2
prom_query "$P99" "p99_seconds"
