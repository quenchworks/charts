{{/* Secret holding the postgres superuser password */}}
{{- define "timescaledb.secretName" -}}
{{- if .Values.auth.existingSecret -}}{{ .Values.auth.existingSecret }}{{- else -}}{{ include "quench-common.fullname" . }}{{- end -}}
{{- end -}}

{{- define "timescaledb.secretPasswordKey" -}}
{{- if .Values.auth.existingSecret -}}{{ .Values.auth.existingSecretPasswordKey }}{{- else -}}postgres-password{{- end -}}
{{- end -}}

{{- define "timescaledb.serviceAccountName" -}}
{{- if .Values.serviceAccount.create -}}{{ default (include "quench-common.fullname" .) .Values.serviceAccount.name }}{{- else -}}{{ default "default" .Values.serviceAccount.name }}{{- end -}}
{{- end -}}

{{/* Headless service name for the StatefulSet */}}
{{- define "timescaledb.headlessName" -}}
{{- printf "%s-headless" (include "quench-common.fullname" .) -}}
{{- end -}}
