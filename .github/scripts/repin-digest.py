#!/usr/bin/env python3
"""Repin a chart's image digest from an image-published dispatch.

Usage: repin-digest.py <app> <sha256:...>

For most apps the app image is the first `digest:` in quench/<app>/values.yaml.
Exporters are metrics sidecars, so their digest lives under the metrics.image
block of their parent chart's values.yaml.
"""
import re
import sys
from pathlib import Path

app, digest = sys.argv[1], sys.argv[2]

# exporter -> parent chart whose metrics.image.digest it repins
EXPORTER_PARENT = {
    "redis-exporter": "redis",
    "postgres-exporter": "postgresql",
}

if app in EXPORTER_PARENT:
    path = Path(f"quench/{EXPORTER_PARENT[app]}/values.yaml")
    pattern = re.compile(r'(metrics:.*?image:.*?digest: ")[^"]*(")', re.S)
else:
    path = Path(f"quench/{app}/values.yaml")
    pattern = re.compile(r'(digest: ")[^"]*(")')  # first match = the app image

if not path.exists():
    sys.exit(f"no chart for {app}")

text = path.read_text()
new = pattern.sub(lambda m: m.group(1) + digest + m.group(2), text, count=1)
path.write_text(new)
print("changed" if new != text else "unchanged")
