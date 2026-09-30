#!/usr/bin/env python3
"""Fail when a chart's default install would log in to its bundled database with the
wrong password.

A chart that copies a subchart's password into its own Secret gets two different random
values on a first install: lookup finds nothing yet, so each chart generates its own.
Every chart's ci values set explicit passwords, so no release gate saw it. This renders
each chart that bundles a database subchart with DEFAULT values and flags a value in the
chart's own Secrets that looks like a DB password or URL but contains none of the
subchart's passwords.

usage: python3 scripts/check-default-passwords.py   (from charts/)
"""
import base64, glob, re, subprocess, sys, yaml

DB = {"postgresql", "mariadb", "mysql", "mongodb", "valkey", "redis", "rabbitmq"}
# Charts whose subchart reads THIS chart's Secret (auth.existingSecret), so the two
# always match even though the values differ in form.
SHARED = {"identity-stack"}
KEY = re.compile(r"pass|pw|uri|url|dsn|conn|datasource", re.I)
DBKEY = re.compile(r"db|database|dsn|uri|url|redis|valkey|mongo|postgres|mysql|maria|conn|datasource", re.I)

bad = 0
for f in sorted(glob.glob("quench/*/Chart.yaml")):
    chart = f.split("/")[1]
    deps = [d["name"] for d in yaml.safe_load(open(f)).get("dependencies") or []]
    dbs = [d for d in deps if d in DB]
    if not dbs or chart in SHARED:
        continue
    subprocess.run(["helm", "dependency", "build", f"quench/{chart}"], capture_output=True)
    r = subprocess.run(["helm", "template", "r", f"quench/{chart}"], capture_output=True, text=True)
    if r.returncode:
        # A chart that refuses to render without a required value is not a silent failure.
        print(f"  {chart}: skipped, needs values to render ({r.stderr.strip().splitlines()[0][:100]})")
        continue
    sub_pw, own = set(), []
    for d in yaml.safe_load_all(r.stdout):
        if not d or d.get("kind") != "Secret":
            continue
        name = d["metadata"]["name"]
        data = {k: base64.b64decode(v).decode(errors="replace") for k, v in (d.get("data") or {}).items()}
        data.update(d.get("stringData") or {})
        is_sub = any(name == f"r-{db}" or name.startswith(f"r-{db}-") for db in dbs)
        for k, v in data.items():
            if is_sub and re.search("pass", k, re.I):
                sub_pw.add(v)
            elif not is_sub and KEY.search(k) and DBKEY.search(k):
                own.append((name, k, v))
    for name, k, v in own:
        looks = re.fullmatch(r"[A-Za-z0-9]{16,}", v) or "://" in v
        if sub_pw and looks and not any(p and p in v for p in sub_pw):
            print(f"  {chart}: {name}/{k} holds a DB credential the bundled {'/'.join(dbs)} does not use")
            bad += 1

if bad:
    print(f"\n{bad} default-install password mismatches; read the password from the subchart's Secret.")
    sys.exit(1)
print("every DB-bundling chart's default install uses the subchart's own password")
