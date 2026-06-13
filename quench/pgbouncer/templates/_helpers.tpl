{{- define "pgbouncer.serviceAccountName" -}}
{{- if .Values.serviceAccount.create -}}{{ default (include "quench-common.fullname" .) .Values.serviceAccount.name }}{{- else -}}{{ default "default" .Values.serviceAccount.name }}{{- end -}}
{{- end -}}

{{/*
Backend database wiring. When postgresql.enabled the bundled subchart's primary Service
is named "<release>-postgresql" (the subchart's quench-common.fullname resolves against
its own chart name "postgresql"); credentials come from this chart's postgresql.auth.
When external, everything comes from externalDatabase.
*/}}
{{- define "pgbouncer.db.host" -}}
{{- if .Values.postgresql.enabled -}}
{{- printf "%s-postgresql" .Release.Name -}}
{{- else -}}
{{- required "externalDatabase.host is required when postgresql.enabled=false" .Values.externalDatabase.host -}}
{{- end -}}
{{- end -}}

{{- define "pgbouncer.db.port" -}}
{{- if .Values.postgresql.enabled -}}5432{{- else -}}{{ .Values.externalDatabase.port }}{{- end -}}
{{- end -}}

{{- define "pgbouncer.db.name" -}}
{{- if .Values.postgresql.enabled -}}{{ .Values.postgresql.auth.database }}{{- else -}}{{ .Values.externalDatabase.database }}{{- end -}}
{{- end -}}

{{- define "pgbouncer.db.user" -}}
{{- if .Values.postgresql.enabled -}}{{ .Values.postgresql.auth.username }}{{- else -}}{{ .Values.externalDatabase.user }}{{- end -}}
{{- end -}}

{{/*
Resolve the backend password (used to build the generated userlist.txt). With the bundled
PG it is the deterministic postgresql.auth.password. With an external DB it is the inline
externalDatabase.password — when an external existingSecret is used instead, the userlist
must be supplied via userlist.existingSecret (we cannot read a Secret at render time).
*/}}
{{- define "pgbouncer.db.password" -}}
{{- if .Values.postgresql.enabled -}}
{{- required "postgresql.auth.password is required when postgresql.enabled=true" .Values.postgresql.auth.password -}}
{{- else -}}
{{- .Values.externalDatabase.password -}}
{{- end -}}
{{- end -}}

{{/* Name of the userlist Secret (the chart-managed one, or a user-provided one). */}}
{{- define "pgbouncer.userlistSecretName" -}}
{{- if .Values.userlist.existingSecret -}}{{ .Values.userlist.existingSecret }}{{- else -}}{{ printf "%s-userlist" (include "quench-common.fullname" .) }}{{- end -}}
{{- end -}}

{{/* Name of the ConfigMap holding pgbouncer.ini. */}}
{{- define "pgbouncer.configMapName" -}}
{{- printf "%s-config" (include "quench-common.fullname" .) -}}
{{- end -}}

{{/*
Render the full pgbouncer.ini. If pgbouncer.raw is set it is used verbatim; otherwise we
generate [databases] (a wildcard route to the backend) + [pgbouncer].
*/}}
{{- define "pgbouncer.ini" -}}
{{- if .Values.pgbouncer.raw -}}
{{ .Values.pgbouncer.raw }}
{{- else -}}
[databases]
* = host={{ include "pgbouncer.db.host" . }} port={{ include "pgbouncer.db.port" . }} dbname={{ include "pgbouncer.db.name" . }}

[pgbouncer]
listen_addr = 0.0.0.0
listen_port = {{ .Values.service.port }}
unix_socket_dir = /var/run/pgbouncer
pidfile = /var/run/pgbouncer/pgbouncer.pid
logfile =
auth_type = {{ .Values.pgbouncer.authType }}
auth_file = /etc/pgbouncer/userlist.txt
admin_users = {{ .Values.pgbouncer.adminUsers }}
pool_mode = {{ .Values.pgbouncer.poolMode }}
max_client_conn = {{ .Values.pgbouncer.maxClientConn }}
default_pool_size = {{ .Values.pgbouncer.defaultPoolSize }}
min_pool_size = {{ .Values.pgbouncer.minPoolSize }}
reserve_pool_size = {{ .Values.pgbouncer.reservePoolSize }}
ignore_startup_parameters = {{ .Values.pgbouncer.ignoreStartupParameters }}
{{- with .Values.pgbouncer.extraConfig }}
{{ . }}
{{- end }}
{{- end -}}
{{- end -}}
