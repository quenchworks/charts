{{- define "mattermost.serviceAccountName" -}}
{{- if .Values.serviceAccount.create -}}{{ default (include "quench-common.fullname" .) .Values.serviceAccount.name }}{{- else -}}{{ default "default" .Values.serviceAccount.name }}{{- end -}}
{{- end -}}

{{/* Headless Service name for the StatefulSet. */}}
{{- define "mattermost.headlessName" -}}
{{- printf "%s-headless" (include "quench-common.fullname" .) | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Database wiring. When postgresql.enabled the bundled subchart's primary Service is
named "<release>-postgresql" (the subchart's quench-common.fullname resolves against
its own chart name "postgresql"); credentials come from this chart's postgresql.auth.
When external, everything comes from externalDatabase.
*/}}
{{- define "mattermost.db.host" -}}
{{- if .Values.postgresql.enabled -}}
{{- printf "%s-postgresql" .Release.Name -}}
{{- else -}}
{{- required "externalDatabase.host is required when postgresql.enabled=false" .Values.externalDatabase.host -}}
{{- end -}}
{{- end -}}

{{- define "mattermost.db.port" -}}
{{- if .Values.postgresql.enabled -}}5432{{- else -}}{{ .Values.externalDatabase.port }}{{- end -}}
{{- end -}}

{{- define "mattermost.db.name" -}}
{{- if .Values.postgresql.enabled -}}{{ .Values.postgresql.auth.database }}{{- else -}}{{ .Values.externalDatabase.database }}{{- end -}}
{{- end -}}

{{- define "mattermost.db.user" -}}
{{- if .Values.postgresql.enabled -}}{{ .Values.postgresql.auth.username }}{{- else -}}{{ .Values.externalDatabase.user }}{{- end -}}
{{- end -}}

{{/* Name of the Secret holding the DB password, and the key within it. */}}
{{- define "mattermost.db.secretName" -}}
{{- if and (not .Values.postgresql.enabled) .Values.externalDatabase.existingSecret -}}
{{- .Values.externalDatabase.existingSecret -}}
{{- else -}}
{{- include "quench-common.fullname" . -}}
{{- end -}}
{{- end -}}

{{- define "mattermost.db.secretPasswordKey" -}}
{{- if and (not .Values.postgresql.enabled) .Values.externalDatabase.existingSecret -}}
{{- .Values.externalDatabase.existingSecretPasswordKey -}}
{{- else -}}
db-password
{{- end -}}
{{- end -}}

{{/*
Resolve the SITEURL. Defaults to the in-cluster service DNS so a bare install boots
with a coherent SiteURL; override with .Values.siteUrl for production.
*/}}
{{- define "mattermost.siteUrl" -}}
{{- if .Values.siteUrl -}}
{{- .Values.siteUrl -}}
{{- else -}}
{{- printf "http://%s.%s.svc.cluster.local:%d" (include "quench-common.fullname" .) .Release.Namespace (int .Values.service.port) -}}
{{- end -}}
{{- end -}}
