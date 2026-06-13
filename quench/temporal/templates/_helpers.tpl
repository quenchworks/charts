{{- define "temporal.serviceAccountName" -}}
{{- if .Values.serviceAccount.create -}}{{ default (include "quench-common.fullname" .) .Values.serviceAccount.name }}{{- else -}}{{ default "default" .Values.serviceAccount.name }}{{- end -}}
{{- end -}}

{{/* Name of the server config ConfigMap. */}}
{{- define "temporal.configMapName" -}}
{{- printf "%s-config" (include "quench-common.fullname" .) -}}
{{- end -}}

{{/*
Database wiring. When postgresql.enabled the bundled subchart's primary Service is
named "<release>-postgresql"; credentials come from this chart's postgresql.auth.
When external, everything comes from externalDatabase. Temporal uses TWO databases:
the main store (databases.main) and the visibility store (databases.visibility).
*/}}
{{- define "temporal.db.host" -}}
{{- if .Values.postgresql.enabled -}}
{{- printf "%s-postgresql" .Release.Name -}}
{{- else -}}
{{- required "externalDatabase.host is required when postgresql.enabled=false" .Values.externalDatabase.host -}}
{{- end -}}
{{- end -}}

{{- define "temporal.db.port" -}}
{{- if .Values.postgresql.enabled -}}5432{{- else -}}{{ .Values.externalDatabase.port }}{{- end -}}
{{- end -}}

{{- define "temporal.db.user" -}}
{{- if .Values.postgresql.enabled -}}{{ .Values.postgresql.auth.username }}{{- else -}}{{ .Values.externalDatabase.user }}{{- end -}}
{{- end -}}

{{/* Main (default) store database name. With the bundled PG this is postgresql.auth.database. */}}
{{- define "temporal.db.mainName" -}}
{{- if .Values.postgresql.enabled -}}{{ .Values.postgresql.auth.database }}{{- else -}}{{ .Values.databases.main }}{{- end -}}
{{- end -}}

{{/* Visibility store database name (created by the schema-setup Job). */}}
{{- define "temporal.db.visibilityName" -}}
{{ .Values.databases.visibility }}
{{- end -}}

{{/*
Resolve the DB password literal. Bundled: postgresql.auth.password. External: the
inline password (or, if an existingSecret is set, the caller is responsible — we
still try the inline value). Used to render the server config and the Job env.
*/}}
{{- define "temporal.db.password" -}}
{{- if .Values.postgresql.enabled -}}{{ .Values.postgresql.auth.password }}{{- else -}}{{ .Values.externalDatabase.password }}{{- end -}}
{{- end -}}

{{/* Name of the Secret that holds the DB password, and the key within it. */}}
{{- define "temporal.db.secretName" -}}
{{- if and (not .Values.postgresql.enabled) .Values.externalDatabase.existingSecret -}}
{{- .Values.externalDatabase.existingSecret -}}
{{- else -}}
{{- include "quench-common.fullname" . -}}
{{- end -}}
{{- end -}}

{{- define "temporal.db.secretPasswordKey" -}}
{{- if and (not .Values.postgresql.enabled) .Values.externalDatabase.existingSecret -}}
{{- .Values.externalDatabase.existingSecretPasswordKey -}}
{{- else -}}
db-password
{{- end -}}
{{- end -}}

{{/*
Render-config script. The QuenchWorks clean image does NOT run dockerize, so the
server config must be plain YAML with no `{{ }}` directives. The ConfigMap (mounted
read-only at /etc/temporal/config-template/) carries the literal placeholder
__POD_IP__; this initContainer substitutes the real pod IP (downward-API POD_IP)
with busybox sed and writes the result onto the shared writable emptyDir mounted at
/etc/temporal/config/ — which is where the server reads `--config config` under
`--root /etc/temporal`. The dynamicconfig file is copied to the path the rendered
config references (dynamicConfigClient.filepath). Runs BEFORE schema-setup.
*/}}
{{- define "temporal.renderConfigScript" -}}
set -eu
mkdir -p /etc/temporal/config/dynamicconfig
sed "s/__POD_IP__/${POD_IP}/g" /etc/temporal/config-template/production.yaml > /etc/temporal/config/production.yaml
cp /etc/temporal/config-template/dynamicconfig.yaml /etc/temporal/config/dynamicconfig/dynamicconfig.yaml
echo "rendered config for POD_IP=${POD_IP}:"
cat /etc/temporal/config/production.yaml
{{- end -}}

{{/*
Schema-setup script. Runs as an initContainer on the server pod so it executes
AFTER the bundled PostgreSQL Deployment exists (helm installs both in one pass and
the loop below handles ordering — a pre-install hook would run before PG is even
created). Temporal needs TWO databases: the main store and the visibility store.
The script:
  1. waits for PostgreSQL by retrying create-database for the main DB (idempotent —
     "already exists" is tolerated) until it succeeds, proving connectivity;
  2. ensures the visibility DB exists;
  3. setup-schema -v 0.0 (creates the version tables) then update-schema -d <dir>/versioned
     to apply every migration up to the latest, for BOTH the main and visibility
     schema dirs shipped at /etc/temporal/schema/postgresql/v12/{temporal,visibility}.
     NOTE: -d must point at the `versioned/` subdir (whose entries are vX.Y dirs), not
     the parent (which holds schema.sql/database.sql) — else zero migrations apply.
Re-running on restart/upgrade is safe (setup-schema idempotent; update-schema no-op
when current). Reads SQL_PASSWORD from the env (Secret); never echoes it.
*/}}
{{- define "temporal.schemaSetupScript" -}}
SQL_HOST="{{ include "temporal.db.host" . }}"
SQL_PORT="{{ include "temporal.db.port" . }}"
SQL_USER="{{ include "temporal.db.user" . }}"
MAIN_DB="{{ include "temporal.db.mainName" . }}"
VIS_DB="{{ include "temporal.db.visibilityName" . }}"
export SQL_PLUGIN="postgres12"
export SQL_HOST SQL_PORT SQL_USER
# SQL_PASSWORD comes from the env (Secret) — never echoed.

run() { temporal-sql-tool "$@"; }

echo "ensuring main database '${MAIN_DB}' (waiting for PostgreSQL at ${SQL_HOST}:${SQL_PORT}) ..."
i=0
until out="$(run --db "${MAIN_DB}" create-database 2>&1)"; rc=$?; \
      [ "$rc" -eq 0 ] || echo "$out" | grep -qiE 'already exists'; do
  i=$((i+1))
  if [ "$i" -ge {{ .Values.schemaSetup.retries }} ]; then
    echo "PostgreSQL not reachable / main db not creatable after {{ .Values.schemaSetup.retries }} attempts"
    echo "$out"; exit 1
  fi
  sleep {{ .Values.schemaSetup.retryInterval }}
done
echo "main database ready."

out="$(run --db "${VIS_DB}" create-database 2>&1)" \
  || echo "$out" | grep -qiE 'already exists' \
  || { echo "$out"; exit 1; }
echo "visibility database ready."

run --db "${MAIN_DB}" setup-schema -v 0.0 || true
run --db "${MAIN_DB}" update-schema -d /etc/temporal/schema/postgresql/v12/temporal/versioned

run --db "${VIS_DB}" setup-schema -v 0.0 || true
run --db "${VIS_DB}" update-schema -d /etc/temporal/schema/postgresql/v12/visibility/versioned

echo "schema setup complete."
{{- end -}}
