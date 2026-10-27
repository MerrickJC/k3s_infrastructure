#!/usr/bin/env bash
# Network errors per node interface and cluster-wide TCP retransmits over
# the idle window - distinguishes "idle" from "idle but struggling"
# (packet loss / flaky links wouldn't show up in the throughput numbers
# from 09/10 at all, since those just measure bytes moved, not failures).
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"
source ./_lib.sh

TX_ERRORS="sum by (instance, device) (increase(node_network_transmit_errs_total{device!=\"lo\"}[${RANGE}]))"
RX_ERRORS="sum by (instance, device) (increase(node_network_receive_errs_total{device!=\"lo\"}[${RANGE}]))"
RETRANSMITS="sum(increase(node_netstat_Tcp_RetransSegs[${RANGE}]))"

pf_start
echo "Query (transmit errors, by node+interface): $TX_ERRORS" >&2
prom_query "$TX_ERRORS" "tx_errors"
echo "Query (receive errors, by node+interface): $RX_ERRORS" >&2
prom_query "$RX_ERRORS" "rx_errors"
echo "Query (TCP retransmitted segments, cluster total): $RETRANSMITS" >&2
prom_query "$RETRANSMITS" "tcp_retransmits"
