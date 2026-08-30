{{- define "hydra.serviceAccountName" -}}
{{- if .Values.serviceAccount.create -}}{{ default (include "quench-common.fullname" .) .Values.serviceAccount.name }}{{- else -}}{{ default "default" .Values.serviceAccount.name }}{{- end -}}
{{- end -}}

{{/*
Database wiring. When postgresql.enabled the bundled subchart's primary Service is
named "<release>-postgresql" (the subchart's quench-common.fullname resolves against
its own chart name "postgresql"); credentials come from this chart's postgresql.auth.
When external, everything comes from externalDatabase.
*/}}
{{- define "hydra.db.host" -}}
{{- if .Values.postgresql.enabled -}}
{{- printf "%s-postgresql" .Release.Name -}}
{{- else -}}
{{- required "externalDatabase.host is required when postgresql.enabled=false" .Values.externalDatabase.host -}}
{{- end -}}
{{- end -}}

{{- define "hydra.db.port" -}}
{{- if .Values.postgresql.enabled -}}5432{{- else -}}{{ .Values.externalDatabase.port }}{{- end -}}
{{- end -}}

{{- define "hydra.db.name" -}}
{{- if .Values.postgresql.enabled -}}{{ .Values.postgresql.auth.database }}{{- else -}}{{ .Values.externalDatabase.database }}{{- end -}}
{{- end -}}

{{- define "hydra.db.user" -}}
{{- if .Values.postgresql.enabled -}}{{ .Values.postgresql.auth.username }}{{- else -}}{{ .Values.externalDatabase.user }}{{- end -}}
{{- end -}}

{{- define "hydra.db.sslMode" -}}
{{- if .Values.postgresql.enabled -}}disable{{- else -}}{{ .Values.externalDatabase.sslMode }}{{- end -}}
{{- end -}}

{{/* Name of the Secret holding the DSN + system secret, and the DSN key within it. */}}
{{- define "hydra.secretName" -}}
{{- if and (not .Values.postgresql.enabled) .Values.externalDatabase.existingSecret -}}
{{- .Values.externalDatabase.existingSecret -}}
{{- else -}}
{{- include "quench-common.fullname" . -}}
{{- end -}}
{{- end -}}

{{- define "hydra.db.secretDsnKey" -}}
{{- if and (not .Values.postgresql.enabled) .Values.externalDatabase.existingSecret -}}
{{- .Values.externalDatabase.existingSecretDsnKey -}}
{{- else -}}
dsn
{{- end -}}
{{- end -}}

{{- define "hydra.secretsSystemKey" -}}
{{- if and (not .Values.postgresql.enabled) .Values.externalDatabase.existingSecret -}}
{{- .Values.externalDatabase.existingSecretSecretsSystemKey -}}
{{- else -}}
secrets-system
{{- end -}}
{{- end -}}

{{/* Whether this chart renders its own managed Secret. */}}
{{- define "hydra.manageSecret" -}}
{{- if or .Values.postgresql.enabled (not .Values.externalDatabase.existingSecret) -}}true{{- end -}}
{{- end -}}
