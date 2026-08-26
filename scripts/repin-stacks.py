#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.10"
# dependencies = []
# ///
"""Re-pin the umbrella STACK charts to new image digests.

    uv run scripts/repin-stacks.py <image> <digest> [<image> <digest> ...]
    uv run scripts/repin-stacks.py --audit

scripts/repin.py handles a chart's own single image. The stacks are different: each pins
SEVERAL other images by digest, so a stack goes stale the moment any member is rebuilt,
and nothing about the member's own chart release touches it. That is the easiest thing in
the catalog to forget, which is why this is a separate, auditable tool.

Two places hold a digest and BOTH must move together:
  values.yaml   image: ghcr.io/quenchworks/images/<name>
                digest: "sha256:..."          <- what actually deploys
  Chart.yaml    artifacthub.io/images: ... <name>@sha256:...   <- what ArtifactHub shows

--audit reports, for every stack, which images it pins and whether the two locations agree.
A mismatch there fails silently: the deployment is correct and ArtifactHub advertises a
digest nobody runs.
"""
from __future__ import annotations

import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
QUENCH = ROOT / "quench"
IMG = "ghcr.io/quenchworks/images"


def stacks() -> list[pathlib.Path]:
    return sorted(p for p in QUENCH.iterdir()
                  if p.is_dir() and (p / "Chart.yaml").exists() and p.name.endswith("-stack"))


def values_pins(text: str) -> dict[str, str]:
    """image name -> digest, from `image: <repo>/<name>` followed by a `digest:` line."""
    out, cur = {}, None
    for line in text.splitlines():
        m = re.search(rf"image:\s*{re.escape(IMG)}/([a-z0-9._-]+)\s*$", line)
        if m:
            cur = m.group(1)
            continue
        m = re.search(r'digest:\s*"(sha256:[0-9a-f]{64})"', line)
        if m and cur:
            out[cur] = m.group(1)
            cur = None
    return out


def chart_pins(text: str) -> dict[str, str]:
    return dict(re.findall(rf"{re.escape(IMG)}/([a-z0-9._-]+)@(sha256:[0-9a-f]{{64}})", text))


def repin_one(stack: pathlib.Path, image: str, digest: str) -> list[str]:
    changed = []
    vp, cp = stack / "values.yaml", stack / "Chart.yaml"

    vt = vp.read_text()
    old = values_pins(vt).get(image)
    if old and old != digest:
        # Replace only the digest line that belongs to THIS image: walk to the image
        # line, then rewrite the next digest line. A global replace of the old digest
        # would also hit an unrelated image that happens to share it.
        lines, cur, hit = vt.splitlines(keepends=True), None, False
        for i, line in enumerate(lines):
            if re.search(rf"image:\s*{re.escape(IMG)}/{re.escape(image)}\s*$", line.rstrip("\n")):
                cur = image
                continue
            if cur and re.search(r'digest:\s*"sha256:[0-9a-f]{64}"', line):
                lines[i] = re.sub(r'"sha256:[0-9a-f]{64}"', f'"{digest}"', line)
                cur, hit = None, True
                break
        if hit:
            vp.write_text("".join(lines))
            changed.append(f"values.yaml {old[7:19]} -> {digest[7:19]}")

    ct = cp.read_text()
    oldc = chart_pins(ct).get(image)
    if oldc and oldc != digest:
        cp.write_text(ct.replace(f"{IMG}/{image}@{oldc}", f"{IMG}/{image}@{digest}"))
        changed.append(f"Chart.yaml {oldc[7:19]} -> {digest[7:19]}")
    return changed


def bump_chart_version(stack: pathlib.Path, note: str) -> str:
    cp = stack / "Chart.yaml"
    t = cp.read_text()
    m = re.search(r"^version:\s*(\S+)", t, re.M)
    parts = m.group(1).split(".")
    parts[-1] = str(int(parts[-1]) + 1)
    new = ".".join(parts)
    t = re.sub(r"^version:\s*\S+", f"version: {new}", t, count=1, flags=re.M)
    block = ("  artifacthub.io/changes: |\n"
             "    - kind: security\n"
             f'      description: "{note}"\n')
    if "artifacthub.io/changes:" in t:
        t = re.sub(r"  artifacthub\.io/changes: \|\n(?:    .*\n)+", block, t, count=1)
    else:
        t = t.replace("  artifacthub.io/images:", block + "  artifacthub.io/images:", 1)
    cp.write_text(t)
    return new


def audit() -> int:
    bad = 0
    for st in stacks():
        vp = values_pins((st / "values.yaml").read_text())
        cp = chart_pins((st / "Chart.yaml").read_text())
        print(f"{st.name}: {len(vp)} deployed pin(s), {len(cp)} advertised")
        for name in sorted(set(vp) | set(cp)):
            v, c = vp.get(name), cp.get(name)
            if v and c and v != c:
                print(f"   MISMATCH {name}: values={v[7:19]} chart={c[7:19]}")
                bad += 1
            elif v and not c:
                print(f"   note     {name}: deployed but NOT advertised in artifacthub.io/images")
            elif c and not v:
                print(f"   note     {name}: advertised but not pinned in values.yaml (subchart?)")
    print("\nmismatches:", bad)
    return 1 if bad else 0


def main() -> int:
    args = sys.argv[1:]
    if not args or args[0] == "--audit":
        return audit()
    if len(args) % 2:
        print(__doc__)
        return 2
    pairs = list(zip(args[::2], args[1::2]))
    for image, digest in pairs:
        if not re.fullmatch(r"sha256:[0-9a-f]{64}", digest):
            print(f"!! malformed digest for {image}: {digest!r}")
            return 3
    touched = {}
    for st in stacks():
        notes = []
        for image, digest in pairs:
            notes += [f"{image}: {c}" for c in repin_one(st, image, digest)]
        if notes:
            names = sorted({n.split(":")[0] for n in notes})
            ver = bump_chart_version(
                st, "Re-pinned " + ", ".join(names) + " to rebuilt 0-CVE image digests.")
            touched[st.name] = (ver, notes)
    if not touched:
        print("no stack pins matched those images; nothing to do")
        return 0
    for name, (ver, notes) in touched.items():
        print(f"ok {name} -> {ver}")
        for n in notes:
            print(f"     {n}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
