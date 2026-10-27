#!/usr/bin/env python3
"""Summarise kube-scheduler scoring from k3s journalctl output.

Usage:
    sudo journalctl -u k3s --since "10 min ago" --no-pager | python3 k3s_scores.py
    python3 k3s_scores.py k3s.log [more.log ...]
    python3 k3s_scores.py k3s.log --format plain     # aligned text instead of markdown
    python3 k3s_scores.py k3s.log -n other-ns        # a different namespace
    python3 k3s_scores.py k3s.log -A                 # every namespace

Only pods in the kleinkram-actions namespace are shown unless -n / -A is given.

Requires scheduler logging at a level that emits the per-plugin lines, e.g.
`vmodule: "schedule_one=10"` in /etc/rancher/k3s/config.yaml.

Plugin names, node names and the number of pods are all discovered from the
log. Each scheduling attempt gets its own section, in the order the pods first
appear in the log. Nodes are sorted by total score (highest first).
"""

import argparse
import re
import sys
from dataclasses import dataclass, field

# klog line: ... file.go:123] "message" key=value key="quoted value" ...
LINE_RE = re.compile(r'\]\s+"(?P<msg>[^"]+)"(?P<rest>.*)$')
KV_RE = re.compile(r'(\w+)=(?:"((?:[^"\\]|\\.)*)"|(\S+))')


@dataclass
class Attempt:
    pod: str
    number: int = 1
    plugin_scores: dict = field(default_factory=dict)  # node -> {plugin: score}
    plugin_order: list = field(default_factory=list)  # plugins by first appearance
    final: dict = field(default_factory=dict)  # node -> final score from the log
    bound_node: str | None = None
    evaluated: str | None = None
    feasible: str | None = None
    error: str | None = None
    done: bool = False  # bound or failed; the next attempt starts fresh

    @property
    def has_data(self):
        return bool(self.plugin_scores or self.final or self.done)

    def total(self, node):
        if node in self.final:
            return self.final[node]
        return sum(self.plugin_scores.get(node, {}).values())

    def nodes_ranked(self):
        nodes = set(self.plugin_scores) | set(self.final)
        return sorted(nodes, key=lambda n: (-self.total(n), n))


def parse_kv(rest):
    return {m.group(1): m.group(2) if m.group(2) is not None else m.group(3)
            for m in KV_RE.finditer(rest)}


def parse(lines, namespace=None):
    """Parse scheduler log lines. If namespace is set, only pods in it are kept."""
    attempts = []  # in order of first appearance
    current = {}  # pod -> open Attempt
    counts = {}  # pod -> number of attempts so far

    def start(pod):
        counts[pod] = counts.get(pod, 0) + 1
        a = Attempt(pod=pod, number=counts[pod])
        attempts.append(a)
        current[pod] = a
        return a

    def get(pod, fresh_ok=True):
        a = current.get(pod)
        if a is None or a.done:
            a = start(pod)
        return a

    for line in lines:
        m = LINE_RE.search(line)
        if not m:
            continue
        msg, kv = m.group("msg"), parse_kv(m.group("rest"))
        pod = kv.get("pod")
        if not pod:
            continue
        # klog prints pods as "<namespace>/<name>"
        if namespace and pod.split("/", 1)[0] != namespace:
            continue

        if msg in ("About to try and schedule pod", "Attempting to schedule pod"):
            a = current.get(pod)
            if a is None or a.has_data:
                start(pod)
        elif msg == "Plugin scored node for pod":
            a = get(pod)
            node, plugin = kv.get("node"), kv.get("plugin")
            if node is None or plugin is None or "score" not in kv:
                continue
            a.plugin_scores.setdefault(node, {})[plugin] = int(kv["score"])
            if plugin not in a.plugin_order:
                a.plugin_order.append(plugin)
        elif msg == "Calculated node's final score for pod":
            a = get(pod)
            if "node" in kv and "score" in kv:
                a.final[kv["node"]] = int(kv["score"])
        elif msg == "Successfully bound pod to node":
            a = get(pod)
            a.bound_node = kv.get("node")
            a.evaluated = kv.get("evaluatedNodes")
            a.feasible = kv.get("feasibleNodes")
            a.done = True
        elif msg.startswith("Unable to schedule pod"):
            a = get(pod)
            a.error = kv.get("err") or msg
            a.done = True

    return [a for a in attempts if a.has_data]


def render_table(headers, rows, fmt):
    if fmt == "markdown":
        out = ["| " + " | ".join(headers) + " |",
               "|" + "|".join("---" if i == 0 else "---:" for i in range(len(headers))) + "|"]
        out += ["| " + " | ".join(r) + " |" for r in rows]
        return "\n".join(out)
    widths = [max(len(h), *(len(r[i]) for r in rows)) if rows else len(h)
              for i, h in enumerate(headers)]

    def fmt_row(r):
        return "  ".join(c.ljust(widths[i]) if i == 0 else c.rjust(widths[i])
                         for i, c in enumerate(r))

    return "\n".join([fmt_row(headers), "  ".join("-" * w for w in widths)]
                     + [fmt_row(r) for r in rows])


def render(attempt, fmt):
    title = attempt.pod + (f" (attempt {attempt.number})" if attempt.number > 1 else "")
    out = [f"### {title}" if fmt == "markdown" else f"== {title} =="]

    if attempt.bound_node:
        info = f"Bound to {attempt.bound_node}"
        if attempt.evaluated is not None:
            info += f" (evaluated {attempt.evaluated}, feasible {attempt.feasible})"
        out.append(info)
    elif attempt.error:
        out.append(f"Not scheduled: {attempt.error}")
    else:
        out.append("No bind or failure seen in this log window.")
    out.append("")

    if not attempt.plugin_scores and not attempt.final:
        out.append("No scoring logged" + (
            " (only one feasible node, so the scheduler skips scoring)."
            if attempt.feasible == "1" else "."))
        return "\n".join(out)

    plugins = list(attempt.plugin_order)
    headers = ["Node"] + plugins + ["Total"]
    rows = []
    for node in attempt.nodes_ranked():
        label = node + (" *" if node == attempt.bound_node else "")
        scores = attempt.plugin_scores.get(node, {})
        rows.append([label] + [str(scores[p]) if p in scores else "-" for p in plugins]
                    + [str(attempt.total(node))])
    out.append(render_table(headers, rows, fmt))
    if attempt.bound_node:
        out.append("\n(* = node the pod was bound to)")
    return "\n".join(out)


def main():
    ap = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    ap.add_argument("files", nargs="*", help="log files (default: read stdin)")
    ap.add_argument("--format", choices=["markdown", "plain"], default="markdown")
    ap.add_argument("-n", "--namespace", default="kleinkram-actions",
                    help="only show pods in this namespace (default: %(default)s)")
    ap.add_argument("-A", "--all-namespaces", action="store_true",
                    help="show pods from every namespace")
    args = ap.parse_args()

    lines = []
    if args.files:
        for path in args.files:
            with open(path, errors="replace") as f:
                lines.extend(f)
    else:
        lines = sys.stdin.read().splitlines()

    namespace = None if args.all_namespaces else args.namespace
    attempts = parse(lines, namespace)
    if not attempts:
        where = f"in namespace {namespace!r}" if namespace else "in the log"
        sys.exit(f"No scheduling entries found {where}. Is scheduler logging "
                 'enabled (e.g. vmodule: "schedule_one=10")?')
    print("\n\n".join(render(a, args.format) for a in attempts))


if __name__ == "__main__":
    main()