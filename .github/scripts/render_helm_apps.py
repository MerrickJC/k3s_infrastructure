#!/usr/bin/env python3
"""
Renders every apps/*/config.yaml with hasHelm: true via `helm template`, to catch a broken
chart bump or values.yaml edit before it reaches the cluster - every app here has ArgoCD
syncPolicy.automated: {prune: true, selfHeal: true} (argocd-management/unified-automation.yaml),
so merging a PR is deploying it, with no post-merge staging step.

Jenkins is excluded - it has its own dedicated jenkins-jcasc-check.yml, which does real JCasC
conflict-detection plus a full boot validation this lightweight check doesn't attempt.
apps/example is excluded - it's a permanently-excluded template folder, not a real app.

Usage: render_helm_apps.py <apps-dir>
"""
import subprocess
import sys
from pathlib import Path

import yaml

EXCLUDED_APPS = {"jenkins", "example"}


def main():
    if len(sys.argv) != 2:
        sys.exit("Usage: render_helm_apps.py <apps-dir>")

    apps_dir = Path(sys.argv[1])
    failures = []
    checked = 0

    for config_path in sorted(apps_dir.glob("*/config.yaml")):
        app = config_path.parent.name
        if app in EXCLUDED_APPS:
            continue

        with open(config_path, encoding="utf-8") as f:
            config = yaml.safe_load(f)

        if not config.get("hasHelm"):
            continue

        helm = config["helm"]
        repo_url = helm["repoURL"]
        chart = helm["chart"]
        version = str(helm["targetRevision"])
        values_path = config_path.parent / "values.yaml"

        checked += 1
        print(f"::group::helm template {app} ({chart}:{version})")

        if repo_url.startswith(("http://", "https://")):
            # Distinct repo name per app avoids collisions between apps that happen to
            # add the same upstream repo under a different local alias.
            repo_name = f"repo-{app}"
            subprocess.run(
                ["helm", "repo", "add", "--force-update", repo_name, repo_url],
                check=True,
            )
            chart_ref = f"{repo_name}/{chart}"
        else:
            chart_ref = f"oci://{repo_url}/{chart}"

        cmd = ["helm", "template", app, chart_ref, "--version", version]
        if values_path.exists():
            cmd += ["-f", str(values_path)]

        result = subprocess.run(cmd, capture_output=True, text=True)
        if result.returncode != 0:
            print(result.stdout)
            print(result.stderr, file=sys.stderr)
            failures.append(app)
        else:
            print(f"OK - {len(result.stdout.splitlines())} lines rendered")

        print("::endgroup::")

    print(f"\nChecked {checked} app(s), {len(failures)} failure(s)")
    if failures:
        print(f"::error::helm template failed for: {', '.join(failures)}")
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
