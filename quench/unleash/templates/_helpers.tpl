{{- define "unleash.adminSecretName" -}}
{{- default (include "quench-common.fullname" .) .Values.admin.existingSecret -}}
{{- end -}}

{{/* The bundled subchart's Service and Secret are both <release>-postgresql. */}}
{{- define "unleash.dbHost" -}}
{{- if .Values.postgresql.enabled -}}{{ printf "%s-postgresql" .Release.Name }}{{- else -}}{{ required "externalDatabase.host is required when postgresql.enabled=false" .Values.externalDatabase.host }}{{- end -}}
{{- end -}}
