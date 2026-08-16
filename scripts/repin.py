#!/usr/bin/env python3
"""Re-pin a chart to a new image digest, and keep its ArtifactHub changelog honest.

    uv run scripts/repin.py <chart> <appVersion> <digest> [--kind security|changed|added] [--desc "..."]

Does the four things a re-pin always needs, as one atomic edit:

  1. values.yaml            image digest  -> the new digest
  2. Chart.yaml             appVersion    -> the new app version
  3. Chart.yaml             artifacthub.io/images digest -> the new digest
  4. Chart.yaml             version       -> patch+1   (ArtifactHub only re-reads
                                                        metadata on a NEW version)

and then REWRITES `artifacthub.io/changes`.

That last step is the point. Bumping the chart without touching `changes` leaves the
previous release's changelog attached to the new version, so ArtifactHub advertises
something the release did not do -- e.g. a pure digest re-pin published under
"High-availability mode: architecture=replication ...". Nobody notices, because the
chart installs perfectly; only the published changelog lies.
"""
from __future__ import annotations

import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent


def bump_patch(v: str) -> str:
    parts = v.strip().split(".")
    parts[-1] = str(int(parts[-1]) + 1)
    return ".".join(parts)


def main() -> int:
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    opts = dict(zip(
        [a.lstrip("-") for a in sys.argv[1:] if a.startswith("--")],
        [sys.argv[i + 1] for i, a in enumerate(sys.argv[1:], start=1) if a.startswith("--")],
    ))
    if len(args) < 3:
        print(__doc__)
        return 2
    chart, appver, digest = args[0], args[1], args[2]
    if not re.fullmatch(r"sha256:[0-9a-f]{64}", digest):
        print(f"!! refusing a malformed digest: {digest!r}")
        return 3

    cdir = ROOT / "quench" / chart
    cy, vy = cdir / "Chart.yaml", cdir / "values.yaml"
    if not cy.exists():
        print(f"!! no such chart: {chart}")
        return 3

    ctext, vtext = cy.read_text(), vy.read_text()

    old = re.search(r"sha256:[0-9a-f]{64}", vtext)
    if not old:
        print(f"!! {chart}: no digest found in values.yaml")
        return 3
    old = old.group(0)

    oldver = re.search(r"^version:\s*(\S+)", ctext, re.M).group(1)
    oldapp = re.search(r'^appVersion:\s*"?([^"\n]+)"?', ctext, re.M).group(1)
    newver = bump_patch(oldver)

    vtext = vtext.replace(old, digest)
    ctext = ctext.replace(old, digest)
    ctext = re.sub(r"^version:\s*\S+", f"version: {newver}", ctext, count=1, flags=re.M)
    ctext = re.sub(r'^appVersion:\s*"?[^"\n]+"?', f'appVersion: "{appver}"', ctext, count=1, flags=re.M)

    kind = opts.get("kind", "changed")
    desc = opts.get("desc") or (
        f"Updated {chart} to {appver} and re-pinned the image to its new 0-CVE digest."
        if appver != oldapp else
        f"Re-pinned {chart} to a rebuilt 0-CVE image digest (no application version change)."
    )
    block = (f"  artifacthub.io/changes: |\n"
             f"    - kind: {kind}\n"
             f'      description: "{desc}"\n')
    if "artifacthub.io/changes:" in ctext:
        ctext = re.sub(r"  artifacthub\.io/changes: \|\n(?:    .*\n)+", block, ctext, count=1)
    else:
        ctext = ctext.replace("  artifacthub.io/images:", block + "  artifacthub.io/images:", 1)

    if old in ctext or old in vtext:
        print(f"!! {chart}: a stale digest survived the rewrite")
        return 3

    cy.write_text(ctext)
    vy.write_text(vtext)
    print(f"ok {chart}: {oldver} -> {newver}, appVersion {oldapp} -> {appver}, digest {digest[7:19]}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
