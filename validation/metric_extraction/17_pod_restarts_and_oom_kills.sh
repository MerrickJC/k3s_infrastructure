#!/usr/bin/env bash
# Pod container restarts and OOM-kill events per pod over the idle window.
# A benchmark that's supposedly "idle" but shows restarts/OOM kills means
# something was unstable independent of load - worth catching before
# trusting the other idle-baseline numbers.
#
# container_oom_events_total depends on a cAdvisor/kernel version that
# exposes OOM accounting; if your kernel/runtime doesn't, this query will
# just come back empty rather than erroring.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"
source ./_lib.sh

RESTARTS="sum by (namespace, pod) (increase(kube_pod_container_status_restarts_total[${RANGE}]))"
OOM_KILLS="sum by (namespace, pod) (increase(container_oom_events_total[${RANGE}]))"

pf_start
echo "Query (container restarts): $RESTARTS" >&2
prom_query "$RESTARTS" "restarts"
echo "Query (OOM kill events): $OOM_KILLS" >&2
prom_query "$OOM_KILLS" "oom_kills"
