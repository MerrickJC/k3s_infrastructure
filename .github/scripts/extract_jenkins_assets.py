#!/usr/bin/env python3
"""
Extracts the plugin list and JCasC config from a `helm template` render of the
Jenkins chart, writing them to disk in the layout the real image expects
(plugins.txt + a casc_configs/ directory), so a local Jenkins container can be
booted against exactly what would actually get deployed.

Usage: extract_jenkins_assets.py <rendered-manifests.yaml> <output-dir>
"""
import os
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


def looks_like_jcasc(content):
    if not isinstance(content, str):
        return False
    return content.strip().startswith(JCASC_ROOT_KEYS)


def main():
    if len(sys.argv) != 3:
        sys.exit("Usage: extract_jenkins_assets.py <rendered-manifests.yaml> <output-dir>")

    rendered_path, out_dir = sys.argv[1], sys.argv[2]

    with open(rendered_path, encoding="utf-8") as f:
        docs = list(yaml.safe_load_all(f))

    plugins_txt = None
    casc_files = {}

    for doc in docs:
        if not doc or doc.get("kind") != "ConfigMap":
            continue
        data = doc.get("data") or {}
        if "plugins.txt" in data and plugins_txt is None:
            plugins_txt = data["plugins.txt"]
        for key, content in data.items():
            if key.endswith(".yaml") and looks_like_jcasc(content):
                casc_files.setdefault(key, content)

    if plugins_txt is None:
        sys.exit("Could not find plugins.txt in the rendered manifests")
    if not casc_files:
        sys.exit("Could not find any JCasC config in the rendered manifests")

    with open(os.path.join(out_dir, "plugins.txt"), "w", encoding="utf-8") as f:
        f.write(plugins_txt)

    casc_dir = os.path.join(out_dir, "casc_configs")
    os.makedirs(casc_dir, exist_ok=True)
    for name, content in casc_files.items():
        with open(os.path.join(casc_dir, name), "w", encoding="utf-8") as f:
            f.write(content)

    print(f"Wrote plugins.txt and {len(casc_files)} JCasC config file(s): {', '.join(sorted(casc_files))}")


if __name__ == "__main__":
    main()
