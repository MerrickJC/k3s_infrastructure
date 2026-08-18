#!/usr/bin/env python3
"""
Detects key-path conflicts between the Jenkins Helm chart's auto-generated default
JCasC config and this repo's custom configScripts.

Mirrors JCasC's own ErrorOnConflictMergeStrategy: it fails on any full key-path
defined by both sources, even when the values are identical. This exists because
that exact failure mode (ConfiguratorConflictException) crash-looped the real
Jenkins pod twice - see apps/jenkins/values.yaml's comments for the history.

Usage: check_jcasc_conflicts.py <rendered-manifests.yaml>
"""
import sys

import yaml

JCASC_ROOT_KEYS = (
    "configuration-as-code:",
    "jenkins:",
    "credentials:",
    "security:",
    "unclassified:",
    "appearance:",
    "tool:",
    "globalCredentialsConfiguration:",
)


def collect_paths(node, prefix=()):
    """Yield every leaf key-path in a nested mapping. Lists are treated as a single
    leaf, matching how JCasC's YAML merge treats sequence nodes."""
    if isinstance(node, dict):
        for key, value in node.items():
            yield from collect_paths(value, prefix + (key,))
    else:
        yield prefix


def looks_like_jcasc(content):
    if not isinstance(content, str):
        return False
    return content.strip().startswith(JCASC_ROOT_KEYS)


def main():
    if len(sys.argv) != 2:
        sys.exit("Usage: check_jcasc_conflicts.py <rendered-manifests.yaml>")

    with open(sys.argv[1], encoding="utf-8") as f:
        docs = list(yaml.safe_load_all(f))

    default_config = None
    custom_configs = {}

    for doc in docs:
        if not doc or doc.get("kind") != "ConfigMap":
            continue
        data = doc.get("data") or {}
        for key, content in data.items():
            if not key.endswith(".yaml"):
                continue
            if key == "jcasc-default-config.yaml":
                if default_config is None and looks_like_jcasc(content):
                    default_config = yaml.safe_load(content)
            elif looks_like_jcasc(content):
                custom_configs.setdefault(key, yaml.safe_load(content))

    if default_config is None:
        print("::warning::Could not find the chart's default JCasC ConfigMap - skipping conflict check")
        return 0

    if not custom_configs:
        print("::warning::Could not find any custom configScripts ConfigMap - skipping conflict check")
        return 0

    default_paths = set(collect_paths(default_config))

    conflicts = []
    for name, config in custom_configs.items():
        custom_paths = set(collect_paths(config))
        for path in default_paths & custom_paths:
            conflicts.append((name, ".".join(str(p) for p in path)))

    if conflicts:
        print("Found key-path conflicts between the chart's auto-generated default JCasC")
        print("config and configScripts. JCasC refuses to boot with these present")
        print("(ConfiguratorConflictException), even if both sides set the same value.\n")
        for name, path in sorted(conflicts):
            print(f"  {name}: {path}")
        print("\nFix: either delete the key from configScripts (if the chart's default")
        print("already matches what you want), or set the corresponding controller.*")
        print("value in values.yaml instead (if it needs to differ from the chart default).")
        return 1

    print("No JCasC key-path conflicts found.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
