{{- define "label-studio.serviceAccountName" -}}
{{- if .Values.serviceAccount.create -}}{{ default (include "quench-common.fullname" .) .Values.serviceAccount.name }}{{- else -}}{{ default "default" .Values.serviceAccount.name }}{{- end -}}
{{- end -}}

{{/*
Database wiring. The bundled subchart's primary Service is "<release>-postgresql".
The PostgreSQL image creates auth.username as the superuser and creates the app
database only when it differs from that user, so keep them distinct.
*/}}
{{- define "label-studio.db.host" -}}
{{- if .Values.postgresql.enabled -}}{{ printf "%s-postgresql" .Release.Name }}{{- else -}}{{ required "externalDatabase.host is required when postgresql.enabled=false and externalDatabase.enabled=true" .Values.externalDatabase.host }}{{- end -}}
{{- end -}}
{{- define "label-studio.db.port" -}}
{{- if .Values.postgresql.enabled -}}5432{{- else -}}{{ .Values.externalDatabase.port }}{{- end -}}
{{- end -}}
{{- define "label-studio.db.name" -}}
{{- if .Values.postgresql.enabled -}}{{ .Values.postgresql.auth.database }}{{- else -}}{{ .Values.externalDatabase.database }}{{- end -}}
{{- end -}}
{{- define "label-studio.db.user" -}}
{{- if .Values.postgresql.enabled -}}{{ .Values.postgresql.auth.username }}{{- else -}}{{ .Values.externalDatabase.user }}{{- end -}}
{{- end -}}
{{/* True when Label Studio uses PostgreSQL; otherwise SQLite on the data PVC. */}}
{{- define "label-studio.db.postgres" -}}
{{- if or .Values.postgresql.enabled .Values.externalDatabase.enabled -}}true{{- end -}}
{{- end -}}
