#!/usr/bin/env bash
# Average CPU usage across the entire cluster over the idle window, in cores.
#
# Uses node_exporter's node_cpu_seconds_total (whole-node, not just
# container cgroups) so it captures kubelet/containerd/OS overhead too -
# this is "how many cores did the whole cluster burn", the right number for
# an idle-baseline figure. mode!="idle" sums every non-idle mode
# (user/system/iowait/irq/...).
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"
source ./_lib.sh

EXPR="avg_over_time((sum(rate(node_cpu_seconds_total{mode!=\"idle\"}[1m])))[${RANGE}:1m])"

pf_start
echo "Query: $EXPR" >&2
prom_query "$EXPR"
