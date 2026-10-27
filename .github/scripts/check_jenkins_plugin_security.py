#!/usr/bin/env python3
"""
Checks this repo's pinned Jenkins plugin versions (controller.additionalPlugins in
apps/jenkins/values.yaml) against the live Jenkins Update Center's published security
warnings feed - the same data Jenkins' own Plugin Manager UI reads to show its
"Warnings have been published for the following currently installed components" banner,
surfaced here as CI output instead of requiring someone to notice it by logging into
Jenkins. This exists because Renovate cannot cover this case: Jenkins plugin advisories
aren't in the OSV/GHSA database Renovate's osvVulnerabilityAlerts checks, and even a
"no fix available" advisory has no new version for any version-bump tool to propose in
the first place.

Usage: check_jenkins_plugin_security.py <path-to-jenkins-values.yaml>
Prints nothing and exits 0 if no pinned plugin is currently affected. Prints a Markdown
report to stdout (still exit 0) if any are - the caller decides what to do with it.
"""
import json
import re
import sys
import urllib.request

import yaml

UPDATE_CENTER_URL = "https://updates.jenkins.io/current/update-center.actual.json"


def load_pinned_plugins(values_path):
    with open(values_path, encoding="utf-8") as f:
        values = yaml.safe_load(f)
    pinned = {}
    for entry in values["controller"]["additionalPlugins"]:
        plugin_id, version = entry.split(":", 1)
        pinned[plugin_id] = version
    return pinned


def numeric_prefix(version):
    """Jenkins plugin versions are typically NUMBER(.NUMBER)*[.vHASH], where the
    trailing ".vHASH" qualifier is release-process metadata (tied to a specific commit)
    rather than an independently orderable segment. This extracts just the leading
    dotted-numeric run for ordering - a deliberate approximation of Jenkins' own
    VersionNumber comparator, good enough to decide "is this warning's range plausibly
    still relevant", not precise enough to trust blindly - always check the advisory
    URL in the report before acting.
    """
    parts = []
    for segment in version.split("."):
        m = re.match(r"\d+", segment)
        if not m:
            break
        parts.append(int(m.group()))
    return tuple(parts)


def is_affected(pinned_version, version_range):
    pattern = version_range.get("pattern", ".*")
    try:
        if not re.fullmatch(pattern, pinned_version):
            return False
    except re.error:
        # Malformed/unsupported regex syntax for this entry - skip rather than crash
        # the whole check over one bad advisory record.
        return False

    pinned_key = numeric_prefix(pinned_version)
    first, last = version_range.get("firstVersion"), version_range.get("lastVersion")
    if first and pinned_key < numeric_prefix(first):
        return False
    if last and pinned_key > numeric_prefix(last):
        return False
    return True


def main():
    if len(sys.argv) != 2:
        sys.exit("Usage: check_jenkins_plugin_security.py <path-to-jenkins-values.yaml>")

    pinned = load_pinned_plugins(sys.argv[1])

    with urllib.request.urlopen(UPDATE_CENTER_URL, timeout=60) as resp:
        data = json.load(resp)

    latest_versions = {name: info.get("version") for name, info in data.get("plugins", {}).items()}

    findings = []
    for warning in data.get("warnings", []):
        if warning.get("type") != "plugin" or warning.get("name") not in pinned:
            continue
        plugin_id = warning["name"]
        pinned_version = pinned[plugin_id]
        for version_range in warning.get("versions") or [{"pattern": ".*"}]:
            if is_affected(pinned_version, version_range):
                findings.append((plugin_id, pinned_version, warning, latest_versions.get(plugin_id)))
                break

    if not findings:
        return

    lines = [
        "The following pinned Jenkins plugins (`controller.additionalPlugins` in "
        "`kubernetes/apps/jenkins/values.yaml`) have a published security "
        f"advisory affecting the currently pinned version, per the "
        f"[Jenkins Update Center]({UPDATE_CENTER_URL}):",
        "",
    ]
    for plugin_id, pinned_version, warning, latest in findings:
        fix_available = latest is not None and numeric_prefix(latest) > numeric_prefix(pinned_version)
        fix_note = f"fixed in `{latest}` - Renovate should pick this up automatically" if fix_available \
            else "no fixed version has been released yet"
        lines.append(
            f"- **{plugin_id}** `{pinned_version}` - "
            f"[{warning['id']}: {warning['message']}]({warning['url']}) ({fix_note})"
        )
    lines.append("")
    lines.append(
        "This list is regenerated from the live Update Center feed on every scheduled run - it "
        "clears itself once a fix is released and applied, or the advisory is withdrawn. Version-range "
        "matching here is an approximation (see `numeric_prefix()` in "
        "`.github/scripts/check_jenkins_plugin_security.py`) - always confirm against the linked "
        "advisory before deciding what to do."
    )
    print("\n".join(lines))


if __name__ == "__main__":
    main()
