#!/usr/bin/env -S uv run --quiet
# /// script
# requires-python = ">=3.11"
# dependencies = ["pyyaml>=6"]
# ///
"""Report parent charts whose `dependencies:` pins lag the actual subchart version.

    uv run scripts/audit-dep-lag.py            # report
    uv run scripts/audit-dep-lag.py --strict   # exit 1 if anything lags (for CI)

WHY THIS EXISTS. A parent chart deploys the subchart VERSION it pins, and that subchart
pins its own image digest. So a lagging pin means image re-pins never reach anyone who
installs the parent -- silently. On 2026-08-27 an audit found 47 such pins across 28
charts: graylog pinned opensearch 0.0.10 against 0.1.5, and fourteen charts pinned
postgresql 0.0.12 against 0.0.18. Every one of those parents was shipping months-old
images while its own leaf chart looked freshly re-pinned.

It reports rather than fixes, because fixing has three traps that need a human:

  ORDERING -- a bumped pin must exist in the OCI registry. Bumping a parent before its
  subchart publishes gives `helm dependency build` a version it cannot resolve.

  CASCADES -- bumping a chart's own version (because ITS deps moved) re-stales every
  parent that pins it. keycloak did exactly this to identity-stack.

  BREAKING VALUES -- a minor subchart bump can invalidate the parent's values. opensearch
  0.1.x moved heap and persistence out of `config` into per-topology sections, so
  graylog's values had to be migrated, not just its pin.

  COMPATIBILITY -- newest is not always right, and neither is oldest. skywalking pinned
  elasticsearch 0.0.10 to stay off ES 9, but OAP 10.4 rejects every ES 9 our elasticsearch
  chart has ever shipped, so the pin was not holding a working combination -- it was
  holding a broken one still. The fix was a different subchart (opensearch, which OAP
  accepts at any major), not a version. A lag can mean the dependency itself is wrong.
"""
from __future__ import annotations

import pathlib
import re
import sys

import yaml

ROOT = pathlib.Path(__file__).resolve().parent.parent


def chart_version(slug: str) -> str | None:
    p = ROOT / "quench" / slug / "Chart.yaml"
    if not p.exists():
        return None
    m = re.search(r"^version:\s*(\S+)", p.read_text(), re.M)
    return m.group(1) if m else None


def main() -> int:
    strict = "--strict" in sys.argv
    lagging: list[tuple[str, str, str, str]] = []
    for d in sorted(p for p in (ROOT / "quench").iterdir() if p.is_dir()):
        cy = d / "Chart.yaml"
        if not cy.exists():
            continue
        doc = yaml.safe_load(cy.read_text()) or {}
        for dep in doc.get("dependencies") or []:
            actual = chart_version(dep["name"])
            if actual and dep.get("version") != actual:
                lagging.append((d.name, dep["name"], dep.get("version"), actual))

    if not lagging:
        print("no lagging subchart pins")
        return 0

    print(f"{len(lagging)} lagging subchart pin(s):")
    for parent, dep, pinned, actual in lagging:
        print(f"  {parent:24s} {dep:18s} pinned {pinned:9s} actual {actual}")
    print(
        "\nA lagging pin means this parent deploys an OLD subchart, which pins an OLD\n"
        "image digest. Before bumping: check the target version is published, re-audit\n"
        "for cascades afterwards, lint the parent (a minor bump can break its values),\n"
        "and confirm the newest version is actually COMPATIBLE -- see the module docstring."
    )
    return 1 if strict else 0


if __name__ == "__main__":
    raise SystemExit(main())
