#!/usr/bin/env python3
"""Fail if any chart pins an image digest the catalog no longer publishes.

    uv run --with pyyaml scripts/check-pins.py [--lock PATH]

Every chart pins by digest, and the digest is the contract with the image
factory. When an image is rebuilt the old digest keeps resolving in GHCR, so a
stale pin installs cleanly and silently ships the CVEs the rebuild fixed. There
is no symptom to notice; the only way to see it is to compare.

on-image-published.yml re-pins the SIMPLE charts automatically and deliberately
skips the multi-image ones, because scripts/repin.py rewrites the first digest
in the file and that is only correct when the first digest is the app's own. It
reports those in the PR body for manual handling. Nothing failed when the manual
handling did not happen, which is how 45 pins across 37 charts went stale before
2026-09-20. This is that missing failure.

The invariant is deliberately weak: every pinned digest must appear in
catalog.lock.yaml. It says nothing about WHICH version a sibling image should
be, because no chart declares that. It only refuses to let a chart deploy an
image the catalog has stopped publishing.
"""
from __future__ import annotations

import argparse
import pathlib
import re
import sys

import yaml

ROOT = pathlib.Path(__file__).resolve().parent.parent
DEFAULT_LOCK = ROOT.parent / "images" / "catalog.lock.yaml"
PIN = re.compile(r'digest:\s*"?(sha256:[0-9a-f]{64})"?')
# Charts spell the repository as `repository:` or, in the stacks, `image:`; both
# with the digest on a later line. An inline ref (`images/<name>@sha256:...`) is
# a pin too, in values.yaml and in Chart.yaml's artifacthub.io/images, which is
# what ArtifactHub tells users to pull.
REPO = re.compile(r'(?:repository|image):\s*"?ghcr\.io/quenchworks/images/([A-Za-z0-9._-]+)"?\s*$')
INLINE = re.compile(r"ghcr\.io/quenchworks/images/([A-Za-z0-9._-]+)@(sha256:[0-9a-f]{64})")


def pins(values: pathlib.Path):
    """Yield (image, digest). A digest belongs to the repository above it."""
    owner = None
    for line in values.read_text().splitlines():
        m = REPO.search(line)
        if m:
            owner = m.group(1)
            continue
        d = PIN.search(line)
        if d and owner:
            yield owner, d.group(1)
            owner = None


def inline_pins(path: pathlib.Path):
    """Yield (image, digest) for every inline name@digest ref in the file."""
    for m in INLINE.finditer(path.read_text()):
        yield m.group(1), m.group(2)


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--lock", type=pathlib.Path, default=DEFAULT_LOCK)
    args = ap.parse_args()
    if not args.lock.exists():
        print(f"lock not found: {args.lock}", file=sys.stderr)
        return 2

    lock = yaml.safe_load(args.lock.read_text())
    published = {
        v["digest"]: (name, v["version"])
        for name, app in lock["apps"].items()
        for v in (app.get("versions") or [])
    }
    shipped = {
        name: [v["version"] for v in (app.get("versions") or [])]
        for name, app in lock["apps"].items()
    }

    total, stale = 0, []
    for chart in sorted((ROOT / "quench").glob("*/")):
        found = set()
        values, meta = chart / "values.yaml", chart / "Chart.yaml"
        if values.exists():
            found |= set(pins(values)) | set(inline_pins(values))
        if meta.exists():
            found |= set(inline_pins(meta))
        for image, digest in sorted(found):
            total += 1
            if digest not in published:
                stale.append((chart.name, image, digest))

    # A chart that bundles a quench subchart deploys whatever image THAT release
    # pinned, so a subchart dependency older than the subchart's current version is a
    # stale pin too, just one values.yaml never shows. 35 charts sat on one until
    # 2026-09-25, 17 of them on a superseded PostgreSQL build.
    charts = {c.parent.name: yaml.safe_load(c.read_text())
              for c in (ROOT / "quench").glob("*/Chart.yaml")}
    lagging = [(name, d["name"], d["version"], charts[d["name"]]["version"])
               for name, c in sorted(charts.items())
               for d in c.get("dependencies") or []
               if d["name"] != "quench-common" and d["name"] in charts
               # only our own subcharts: dapr's dependency is upstream's chart, also "dapr"
               and d.get("repository", "").rstrip("/") == "oci://ghcr.io/quenchworks/charts"
               and str(d["version"]) != str(charts[d["name"]]["version"])]
    for chart, sub, have, want in lagging:
        print(f"  {chart} bundles {sub} {have}, current is {want}")
    if lagging:
        print(f"\n{len(lagging)} subchart dependencies lag; bump them and re-release.\n")

    if not stale:
        print(f"all {total} pins are published in the catalog")
        return 1 if lagging else 0

    print(f"{len(stale)} of {total} pins are NOT in the catalog lock:\n")
    for chart, image, digest in stale:
        have = ", ".join(shipped.get(image, [])) or "image not in the catalog at all"
        print(f"  {chart}/{image}")
        print(f"    pinned  {digest}")
        print(f"    catalog {have}")
    print("\nRe-pin with scripts/repin.py (primary image) or by hand (siblings).")
    return 1


if __name__ == "__main__":
    raise SystemExit(main())
