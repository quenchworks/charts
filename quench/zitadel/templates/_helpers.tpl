{{- define "zitadel.serviceAccountName" -}}
{{- if .Values.serviceAccount.create -}}{{ default (include "quench-common.fullname" .) .Values.serviceAccount.name }}{{- else -}}{{ default "default" .Values.serviceAccount.name }}{{- end -}}
{{- end -}}

{{/*
Database wiring. When postgresql.enabled the bundled subchart's primary Service is
named "<release>-postgresql" (the subchart's quench-common.fullname resolves against
its own chart name "postgresql"). The bundled PostgreSQL image creates POSTGRES_USER
(= postgresql.auth.username) as the SUPERUSER, so ZITADEL's runtime user AND its
schema-creating admin user are BOTH that same role — there is no separate "postgres"
superuser when POSTGRES_USER is overridden. When external, runtime and admin
credentials come from externalDatabase.* separately.
*/}}
{{- define "zitadel.db.host" -}}
{{- if .Values.postgresql.enabled -}}
{{- printf "%s-postgresql" .Release.Name -}}
{{- else -}}
{{- required "externalDatabase.host is required when postgresql.enabled=false" .Values.externalDatabase.host -}}
{{- end -}}
{{- end -}}

{{- define "zitadel.db.port" -}}
{{- if .Values.postgresql.enabled -}}5432{{- else -}}{{ .Values.externalDatabase.port }}{{- end -}}
{{- end -}}

{{- define "zitadel.db.name" -}}
{{- if .Values.postgresql.enabled -}}{{ .Values.postgresql.auth.database }}{{- else -}}{{ .Values.externalDatabase.database }}{{- end -}}
{{- end -}}

{{/* Runtime DB user ZITADEL connects as. */}}
{{- define "zitadel.db.user" -}}
{{- if .Values.postgresql.enabled -}}{{ .Values.postgresql.auth.username }}{{- else -}}{{ .Values.externalDatabase.user }}{{- end -}}
{{- end -}}

{{/* Admin (schema-creating) DB user. Equals the bundled superuser when bundled. */}}
{{- define "zitadel.db.adminUser" -}}
{{- if .Values.postgresql.enabled -}}{{ .Values.postgresql.auth.username }}{{- else -}}{{ .Values.externalDatabase.adminUsername }}{{- end -}}
{{- end -}}

{{- define "zitadel.db.sslMode" -}}
{{- if .Values.postgresql.enabled -}}disable{{- else -}}{{ .Values.externalDatabase.sslMode }}{{- end -}}
{{- end -}}

{{/* Name of the Secret holding the managed DB/master/admin material. */}}
{{- define "zitadel.secretName" -}}
{{- if and (not .Values.postgresql.enabled) .Values.externalDatabase.existingSecret -}}
{{- .Values.externalDatabase.existingSecret -}}
{{- else -}}
{{- include "quench-common.fullname" . -}}
{{- end -}}
{{- end -}}

{{/* Whether this chart renders its own managed Secret. */}}
{{- define "zitadel.manageSecret" -}}
{{- if or .Values.postgresql.enabled (not .Values.externalDatabase.existingSecret) -}}true{{- end -}}
{{- end -}}

{{/* Secret keys for the runtime and admin DB passwords. */}}
{{- define "zitadel.db.userPasswordKey" -}}
{{- if and (not .Values.postgresql.enabled) .Values.externalDatabase.existingSecret -}}
{{- .Values.externalDatabase.existingSecretUserPasswordKey -}}
{{- else -}}
db-user-password
{{- end -}}
{{- end -}}

{{- define "zitadel.db.adminPasswordKey" -}}
{{- if and (not .Values.postgresql.enabled) .Values.externalDatabase.existingSecret -}}
{{- .Values.externalDatabase.existingSecretAdminPasswordKey -}}
{{- else -}}
db-admin-password
{{- end -}}
{{- end -}}

{{/* True when the pod must read the DB password from the bundled PostgreSQL chart's Secret:
     the subchart generated it (or reads an existingSecret), so this chart cannot know it
     at render time. lookup finds nothing on a first install, and a copy generated here
     would never match. The bundled superuser serves both the runtime and admin roles. */}}
{{- define "zitadel.db.fromSubchart" -}}
{{- if and .Values.postgresql.enabled (not .Values.postgresql.auth.password) -}}true{{- end -}}
{{- end -}}

{{- define "zitadel.db.subchartSecretRef" -}}
name: {{ .Values.postgresql.auth.existingSecret | default (printf "%s-postgresql" .Release.Name) }}
key: {{ ternary (.Values.postgresql.auth.existingSecretPasswordKey | default "postgres-password") "postgres-password" (not (empty .Values.postgresql.auth.existingSecret)) }}
{{- end -}}
