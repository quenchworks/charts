#!/usr/bin/env python3
"""Repin a chart's image digest from an image-published dispatch.

Usage: repin-digest.py <app> <sha256:...>

For most apps the app image is the first `digest:` in quench/<app>/values.yaml.
Exporters are metrics sidecars, so their digest lives under the metrics.image block
of their parent chart(s). One exporter can feed more than one chart (the redis
exporter is the metrics sidecar for both the redis and valkey charts).
"""
import re
import sys
from pathlib import Path

app, digest = sys.argv[1], sys.argv[2]

# exporter -> the chart(s) whose metrics.image.digest it repins
EXPORTER_PARENTS = {
    "redis-exporter": ["redis", "valkey"],
    "postgres-exporter": ["postgresql"],
}

METRICS_RE = re.compile(r'(metrics:.*?image:.*?digest: ")[^"]*(")', re.S)
FIRST_RE = re.compile(r'(digest: ")[^"]*(")')  # first match = the app image

if app in EXPORTER_PARENTS:
    targets = [(Path(f"quench/{p}/values.yaml"), METRICS_RE) for p in EXPORTER_PARENTS[app]]
else:
    targets = [(Path(f"quench/{app}/values.yaml"), FIRST_RE)]

for path, pattern in targets:
    if not path.exists():
        # image published but no chart references it yet; nothing to repin
        print(f"no chart at {path}, skipping")
        continue
    text = path.read_text()
    new = pattern.sub(lambda m: m.group(1) + digest + m.group(2), text, count=1)
    path.write_text(new)
    print(f"{path}: {'changed' if new != text else 'unchanged'}")
