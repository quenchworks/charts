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
REPO = re.compile(r"repository:\s*ghcr\.io/quenchworks/images/([A-Za-z0-9._-]+)")


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
    for values in sorted((ROOT / "quench").glob("*/values.yaml")):
        for image, digest in pins(values):
            total += 1
            if digest not in published:
                stale.append((values.parent.name, image, digest))

    if not stale:
        print(f"all {total} pins are published in the catalog")
        return 0

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
