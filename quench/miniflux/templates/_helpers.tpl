{{/* ServiceAccount name for the miniflux pod. */}}
{{- define "miniflux.serviceAccountName" -}}
{{- if .Values.serviceAccount.create -}}
{{- default (include "quench-common.fullname" .) .Values.serviceAccount.name -}}
{{- else -}}
{{- default "default" .Values.serviceAccount.name -}}
{{- end -}}
{{- end -}}

{{/*
Hostname of the database. With the bundled subchart the Service is named
"<release>-postgresql" (the subchart reuses quench-common.fullname with chart
name "postgresql"); otherwise it is the externally provided host.
*/}}
{{- define "miniflux.dbHost" -}}
{{- if .Values.postgresql.enabled -}}
{{- printf "%s-postgresql" .Release.Name -}}
{{- else -}}
{{- required "externalDatabase.host is required when postgresql.enabled=false" .Values.externalDatabase.host -}}
{{- end -}}
{{- end -}}

{{/* Full DATABASE_URL connection string. */}}
{{- define "miniflux.databaseURL" -}}
{{- if .Values.postgresql.enabled -}}
{{- $user := .Values.postgresql.auth.username -}}
{{- $pass := required "postgresql.auth.password is required (it is shared with miniflux's DATABASE_URL)" .Values.postgresql.auth.password -}}
{{- $db := .Values.postgresql.auth.database -}}
{{- printf "postgres://%s:%s@%s:5432/%s?sslmode=disable" (urlquery $user) (urlquery $pass) (include "miniflux.dbHost" .) $db -}}
{{- else -}}
{{- $user := .Values.externalDatabase.user -}}
{{- $pass := .Values.externalDatabase.password -}}
{{- $db := .Values.externalDatabase.database -}}
{{- $port := .Values.externalDatabase.port | toString -}}
{{- printf "postgres://%s:%s@%s:%s/%s?sslmode=%s" (urlquery $user) (urlquery $pass) (include "miniflux.dbHost" .) $port $db .Values.externalDatabase.sslmode -}}
{{- end -}}
{{- end -}}

{{/* Whether this chart creates its own Secret (for the DB URL and/or admin password). */}}
{{- define "miniflux.createsSecret" -}}
{{- $ownsURL := or .Values.postgresql.enabled (not .Values.externalDatabase.existingSecret) -}}
{{- $ownsAdmin := and .Values.admin.create (not .Values.admin.existingSecret) -}}
{{- if or $ownsURL $ownsAdmin -}}true{{- end -}}
{{- end -}}

{{/* Secret + key holding the DATABASE_URL consumed by the pod. */}}
{{- define "miniflux.dbSecretName" -}}
{{- if and (not .Values.postgresql.enabled) .Values.externalDatabase.existingSecret -}}
{{- .Values.externalDatabase.existingSecret -}}
{{- else -}}
{{- include "quench-common.fullname" . -}}
{{- end -}}
{{- end -}}

{{- define "miniflux.dbURLKey" -}}
{{- if and (not .Values.postgresql.enabled) .Values.externalDatabase.existingSecret -}}
{{- .Values.externalDatabase.existingSecretURLKey -}}
{{- else -}}
database-url
{{- end -}}
{{- end -}}

{{/* Secret + key holding the admin password consumed by the pod. */}}
{{- define "miniflux.adminSecretName" -}}
{{- if .Values.admin.existingSecret -}}
{{- .Values.admin.existingSecret -}}
{{- else -}}
{{- include "quench-common.fullname" . -}}
{{- end -}}
{{- end -}}

{{- define "miniflux.adminPasswordKey" -}}
{{- if .Values.admin.existingSecret -}}
{{- .Values.admin.existingSecretPasswordKey -}}
{{- else -}}
admin-password
{{- end -}}
{{- end -}}

{{/*
Admin password: explicit value, else the one already persisted in our Secret,
else a fresh random one. Referenced only from the Secret template so it stays
stable across upgrades.
*/}}
{{- define "miniflux.adminPassword" -}}
{{- if .Values.admin.password -}}
{{- .Values.admin.password -}}
{{- else -}}
{{- $name := include "quench-common.fullname" . -}}
{{- $existing := lookup "v1" "Secret" .Release.Namespace $name -}}
{{- if and $existing (index (default dict $existing.data) "admin-password") -}}
{{- index $existing.data "admin-password" | b64dec -}}
{{- else -}}
{{- randAlphaNum 20 -}}
{{- end -}}
{{- end -}}
{{- end -}}
