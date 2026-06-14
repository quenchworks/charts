{{/* Headless service backing the StatefulSet (stable pod DNS). */}}
{{- define "gitea.headlessName" -}}
{{- printf "%s-headless" (include "quench-common.fullname" .) -}}
{{- end -}}

{{/* ConfigMap holding the rendered app.ini template (seeded into the writable
     /etc/gitea by the init flow). */}}
{{- define "gitea.configMapName" -}}
{{- printf "%s-config" (include "quench-common.fullname" .) -}}
{{- end -}}

{{- define "gitea.serviceAccountName" -}}
{{- if .Values.serviceAccount.create -}}{{ default (include "quench-common.fullname" .) .Values.serviceAccount.name }}{{- else -}}{{ default "default" .Values.serviceAccount.name }}{{- end -}}
{{- end -}}

{{/* Secret holding the admin bootstrap user + password (+ db-password +
     SECRET_KEY / INTERNAL_TOKEN). */}}
{{- define "gitea.secretName" -}}
{{- if .Values.auth.existingSecret -}}{{ .Values.auth.existingSecret }}{{- else -}}{{ include "quench-common.fullname" . }}{{- end -}}
{{- end -}}

{{- define "gitea.secretUserKey" -}}
{{- if .Values.auth.existingSecret -}}{{ .Values.auth.existingSecretUserKey }}{{- else -}}admin-user{{- end -}}
{{- end -}}

{{- define "gitea.secretPasswordKey" -}}
{{- if .Values.auth.existingSecret -}}{{ .Values.auth.existingSecretPasswordKey }}{{- else -}}admin-password{{- end -}}
{{- end -}}

{{/*
Database wiring. When postgresql.enabled the bundled subchart's primary Service is
named "<release>-postgresql"; credentials come from this chart's postgresql.auth.
When external, everything comes from externalDatabase.
*/}}
{{- define "gitea.db.host" -}}
{{- if .Values.postgresql.enabled -}}
{{- printf "%s-postgresql" .Release.Name -}}
{{- else -}}
{{- required "externalDatabase.host is required when postgresql.enabled=false" .Values.externalDatabase.host -}}
{{- end -}}
{{- end -}}

{{- define "gitea.db.port" -}}
{{- if .Values.postgresql.enabled -}}5432{{- else -}}{{ .Values.externalDatabase.port }}{{- end -}}
{{- end -}}

{{- define "gitea.db.name" -}}
{{- if .Values.postgresql.enabled -}}{{ .Values.postgresql.auth.database }}{{- else -}}{{ .Values.externalDatabase.database }}{{- end -}}
{{- end -}}

{{- define "gitea.db.user" -}}
{{- if .Values.postgresql.enabled -}}{{ .Values.postgresql.auth.username }}{{- else -}}{{ .Values.externalDatabase.user }}{{- end -}}
{{- end -}}

{{/* Name of the Secret that holds the DB password, and the key within it. */}}
{{- define "gitea.db.secretName" -}}
{{- if .Values.postgresql.enabled -}}
{{- include "quench-common.fullname" . -}}
{{- else if .Values.externalDatabase.existingSecret -}}
{{- .Values.externalDatabase.existingSecret -}}
{{- else -}}
{{- include "quench-common.fullname" . -}}
{{- end -}}
{{- end -}}

{{- define "gitea.db.secretPasswordKey" -}}
{{- if .Values.postgresql.enabled -}}
db-password
{{- else if .Values.externalDatabase.existingSecret -}}
{{- .Values.externalDatabase.existingSecretPasswordKey -}}
{{- else -}}
db-password
{{- end -}}
{{- end -}}
