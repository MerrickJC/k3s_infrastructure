#!/usr/bin/env bash
# Shared helpers sourced by every N_*.sh script in this folder.
#
# Talks directly to the Prometheus HTTP API (the same TSDB Grafana's
# "Prometheus" datasource proxies to - see additionalDataSources.url in
# apps/kube-prometheus-stack/values.yaml) via `kubectl port-forward`. This
# sidesteps the Dex OIDC login Grafana itself requires, which has no
# scriptable non-interactive flow; the data returned is identical to what
# Grafana would show for the same PromQL query.
#
# Override the idle window by exporting WINDOW_START / WINDOW_END (any
# `date -d`-parseable string) before running a script. Both are interpreted
# as UTC (Prometheus itself always stores/queries in UTC), regardless of
# the local timezone of whoever runs the script. Pass an explicit offset
# (e.g. WINDOW_START="2026-10-09T13:00:00+10:00") if you ever want to give
# a non-UTC wall-clock time instead.

set -euo pipefail

WINDOW_START="${WINDOW_START:-2026-10-09T13:00:00}"
WINDOW_END="${WINDOW_END:-2026-10-09T21:00:00}"

START_EPOCH=$(TZ=UTC date -d "$WINDOW_START" +%s)
END_EPOCH=$(TZ=UTC date -d "$WINDOW_END" +%s)
DURATION_S=$((END_EPOCH - START_EPOCH))
if [ "$DURATION_S" -le 0 ]; then
  echo "WINDOW_END ($WINDOW_END) must be after WINDOW_START ($WINDOW_START)" >&2
  exit 1
fi
RANGE="${DURATION_S}s"

PROM_NAMESPACE="observability"
PROM_SVC="svc/kube-prometheus-stack-prometheus"
PROM_LOCAL_PORT="${PROM_LOCAL_PORT:-9090}"

# Every prom_query() call also saves its raw JSON response under results/,
# named after the calling script (plus an optional label for scripts that
# run more than one query) so figures can be pulled into the paper without
# re-running anything or copying terminal output by hand.
SCRIPT_NAME="$(basename "$0" .sh)"
RESULTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/results"
mkdir -p "$RESULTS_DIR"

_PF_PID=""

pf_start() {
  kubectl port-forward -n "$PROM_NAMESPACE" "$PROM_SVC" "${PROM_LOCAL_PORT}:9090" \
    >/tmp/prom-port-forward.log 2>&1 &
  _PF_PID=$!
  trap pf_stop EXIT INT TERM

  for _ in $(seq 1 20); do
    if curl -s -o /dev/null "http://localhost:${PROM_LOCAL_PORT}/-/ready"; then
      return 0
    fi
    sleep 0.5
  done
  echo "Prometheus port-forward never became ready - check /tmp/prom-port-forward.log" >&2
  exit 1
}

pf_stop() {
  if [ -n "$_PF_PID" ]; then
    kill "$_PF_PID" >/dev/null 2>&1 || true
  fi
}

# Reduces a Prometheus instant-query response down to just the number(s):
# a single series with no labels (the common cluster-wide case) becomes a
# bare number; multiple/labelled series become a flat {"labels": value}
# object, keyed by that series' label set, so you still know which row is
# which namespace/pod without carrying the rest of the Prometheus envelope.
simplify_json() {
  local resp="$1"
  if command -v jq >/dev/null 2>&1; then
    printf '%s' "$resp" | jq -c '
      if (.data.result | length) == 1 and (.data.result[0].metric | length) == 0
      then (.data.result[0].value[1] | tonumber)
      else
        ([ .data.result[] | {(( .metric | to_entries | map("\(.key)=\(.value)") | sort | join(",") )): (.value[1] | tonumber)} ] | add)
      end
    '
  elif command -v python3 >/dev/null 2>&1 || command -v python >/dev/null 2>&1; then
    local py
    py=$(command -v python3 || command -v python)
    printf '%s' "$resp" | "$py" -c '
import json, sys
resp = json.load(sys.stdin)
results = resp.get("data", {}).get("result", [])
if len(results) == 1 and not results[0].get("metric"):
    print(results[0]["value"][1])
else:
    out = {}
    for r in results:
        key = ",".join(f"{k}={v}" for k, v in sorted(r.get("metric", {}).items()))
        out[key] = float(r["value"][1])
    print(json.dumps(out))
'
  else
    printf '%s' "$resp"
  fi
}

# prom_query <promql> [label] [time_epoch]  (time defaults to WINDOW_END)
# [label] distinguishes multiple results/*.json files when a script issues
# more than one query (e.g. a "total" and a "rate" variant).
prom_query() {
  local expr="$1"
  local label="${2:-}"
  local at="${3:-$END_EPOCH}"
  local resp
  resp=$(curl -sG "http://localhost:${PROM_LOCAL_PORT}/api/v1/query" \
    --data-urlencode "query=${expr}" \
    --data-urlencode "time=${at}")

  local outfile="${RESULTS_DIR}/${SCRIPT_NAME}${label:+_$label}.json"
  simplify_json "$resp" > "$outfile"
  echo "Saved -> $outfile" >&2

  if command -v jq >/dev/null 2>&1; then
    echo "$resp" | jq .
  elif command -v python3 >/dev/null 2>&1; then
    echo "$resp" | python3 -m json.tool
  elif command -v python >/dev/null 2>&1; then
    echo "$resp" | python -m json.tool
  else
    echo "$resp"
  fi
}

# Resolution (seconds) for prom_query_range's time series. Override via
# RANGE_STEP before running a script that uses it - default matches
# kube-prometheus-stack's default 30s scrape interval, so points line up
# with real scrapes instead of being interpolated between them.
RANGE_STEP_S="${RANGE_STEP:-30}"

# Reduces a Prometheus range-query (matrix) response to
# {"<labels>": [[ts, value], ...], ...} - one entry per series, keyed the
# same way as simplify_json's multi-series case, so a plotting script can
# go straight from this file to a line per series without touching the
# Prometheus response envelope.
simplify_range_json() {
  local resp="$1"
  if command -v jq >/dev/null 2>&1; then
    printf '%s' "$resp" | jq -c '
      [ .data.result[] | {(( .metric | to_entries | map("\(.key)=\(.value)") | sort | join(",") )): [ .values[] | [.[0], (.[1] | tonumber)] ]} ] | (if length == 0 then {} else add end)
    '
  elif command -v python3 >/dev/null 2>&1 || command -v python >/dev/null 2>&1; then
    local py
    py=$(command -v python3 || command -v python)
    printf '%s' "$resp" | "$py" -c '
import json, sys
resp = json.load(sys.stdin)
results = resp.get("data", {}).get("result", [])
out = {}
for r in results:
    key = ",".join(f"{k}={v}" for k, v in sorted(r.get("metric", {}).items())) or "value"
    out[key] = [[ts, float(v)] for ts, v in r.get("values", [])]
print(json.dumps(out))
'
  else
    printf '%s' "$resp"
  fi
}

# prom_query_range <promql> [label] [start_epoch] [end_epoch] [step_s]
# start/end default to the script's WINDOW_START/WINDOW_END, step defaults
# to RANGE_STEP_S. Saves the simplified {labels: [[ts,value],...]} matrix to
# results/ the same way prom_query saves a single value/snapshot - that
# file is what you'd feed a plotting script to draw the time series.
#
# Unlike prom_query, this does NOT dump the raw response to stdout - a
# multi-hour window at 30s resolution is thousands of points, which would
# just flood the terminal. It prints a one-line summary instead.
prom_query_range() {
  local expr="$1"
  local label="${2:-}"
  local start="${3:-$START_EPOCH}"
  local end="${4:-$END_EPOCH}"
  local step="${5:-$RANGE_STEP_S}"
  local resp
  resp=$(curl -sG "http://localhost:${PROM_LOCAL_PORT}/api/v1/query_range" \
    --data-urlencode "query=${expr}" \
    --data-urlencode "start=${start}" \
    --data-urlencode "end=${end}" \
    --data-urlencode "step=${step}")

  local outfile="${RESULTS_DIR}/${SCRIPT_NAME}${label:+_$label}.json"
  simplify_range_json "$resp" > "$outfile"
  echo "Saved -> $outfile" >&2

  if command -v jq >/dev/null 2>&1; then
    local status series
    status=$(printf '%s' "$resp" | jq -r '.status')
    series=$(printf '%s' "$resp" | jq -r '.data.result | length')
    echo "Status: $status, series: $series, step: ${step}s" >&2
    if [ "$status" != "success" ]; then
      echo "$resp" | jq .
    fi
  else
    echo "$resp"
  fi
}

echo "# Window: $WINDOW_START -> $WINDOW_END  (${DURATION_S}s)" >&2
