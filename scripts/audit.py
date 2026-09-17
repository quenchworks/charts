#!/usr/bin/env python3
"""Check that each chart tells the truth about the image it ships.

    uv run scripts/audit.py          # both checks
    uv run scripts/audit.py --drift  # only the annotation-vs-values check
    uv run scripts/audit.py --stale  # only the appVersion-vs-recipe check

Two ways a chart can be internally wrong while linting clean, installing fine
and releasing green. Both were found by hand on 2026-09-17; this is that sweep.

DRIFT  artifacthub.io/images pins one digest and values.yaml pins another.
       ArtifactHub scans the annotation; the cluster runs values.yaml. When they
       disagree the published CVE report describes an image nobody is running,
       and it reads clean either way, so nothing surfaces it. 5 of 166 charts
       had drifted: contour, kyverno, tekton, kgateway, nginx-gateway-fabric.
       repin.py caused at least one of them and now refuses rather than
       reporting ok, but a chart edited by hand can still drift.

STALE  the chart's appVersion is a version its recipe no longer builds, so
       nothing will ever rebuild the image it pins. Expected and unavoidable for
       a BLOCKED app whose recipe moved on without it, which is why those are
       reported separately. The rest are real: envoy-gateway was simply behind.

Sibling images (postgresql, valkey, redis) are pinned in a subchart's own
values.yaml, so they are legitimately absent from the parent and are skipped.
The check is deliberately limited to the image whose repository name matches the
chart, because that is the one this chart is responsible for.
"""
import argparse
import pathlib
import re
import subprocess
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
IMAGES = ROOT.parent / "images"
ANN = re.compile(r"image: ghcr\.io/quenchworks/images/([\w.-]+)@(sha256:[0-9a-f]{64})")


def own_digest(slug: str, vtext: str) -> str | None:
    """The digest under this chart's OWN image block in values.yaml."""
    m = re.search(
        rf"repository: ghcr\.io/quenchworks/images/{re.escape(slug)}\s*\n(?:.*\n){{0,4}}?\s*digest:\s*\"?(sha256:[0-9a-f]{{64}})",
        vtext,
    )
    return m.group(1) if m else None


def recipe_versions(slug: str) -> tuple[list[str], bool] | None:
    conf = IMAGES / "apps" / slug / "build.conf"
    if not conf.exists():
        return None
    blocked = any(l.startswith("BLOCKED=1") for l in conf.read_text().splitlines())
    # Source it: several recipes compute VERSIONS, and zsh does not word-split.
    r = subprocess.run(
        ["bash", "-c", f'cd "{conf.parent}" && source build.conf && echo "${{VERSIONS[@]}}"'],
        capture_output=True, text=True,
    )
    return (r.stdout.split(), blocked)


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--drift", action="store_true")
    ap.add_argument("--stale", action="store_true")
    args = ap.parse_args()
    run_drift = args.drift or not args.stale
    run_stale = args.stale or not args.drift

    drift, stale, blocked_stale, n = [], [], [], 0
    for cy in sorted((ROOT / "quench").glob("*/Chart.yaml")):
        slug = cy.parent.name
        vy = cy.parent / "values.yaml"
        if not vy.exists():
            continue
        n += 1
        ctext, vtext = cy.read_text(), vy.read_text()

        if run_drift:
            ann = dict(ANN.findall(ctext))
            want = own_digest(slug, vtext)
            if slug in ann and want and ann[slug] != want:
                drift.append((slug, ann[slug], want))

        if run_stale:
            app = re.search(r'^appVersion:\s*"?([^"\n]+)"?', ctext, re.M)
            rv = recipe_versions(slug)
            if app and rv and rv[0] and app.group(1).strip() not in rv[0]:
                (blocked_stale if rv[1] else stale).append((slug, app.group(1).strip(), " ".join(rv[0])))

    if run_drift:
        print(f"DRIFT  artifacthub.io/images disagrees with values.yaml: {len(drift)}")
        for slug, a, v in drift:
            print(f"  {slug:<26} annotation={a[:19]}...  values={v[:19]}...")
    if run_stale:
        print(f"STALE  appVersion the recipe no longer builds: {len(stale)} "
              f"({len(blocked_stale)} more in BLOCKED apps, expected)")
        for slug, app, vers in stale:
            print(f"  {slug:<26} ships {app:<12} recipe builds {vers}")

    print(f"\nchecked {n} charts")
    return 1 if (drift or stale) else 0


if __name__ == "__main__":
    raise SystemExit(main())
