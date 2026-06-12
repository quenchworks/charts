{{/* Secret holding the admin password + admin token */}}
{{- define "influxdb.secretName" -}}
{{- if .Values.auth.existingSecret -}}{{ .Values.auth.existingSecret }}{{- else -}}{{ include "quench-common.fullname" . }}{{- end -}}
{{- end -}}

{{- define "influxdb.secretPasswordKey" -}}
{{- if .Values.auth.existingSecret -}}{{ .Values.auth.existingSecretPasswordKey }}{{- else -}}admin-password{{- end -}}
{{- end -}}

{{- define "influxdb.secretTokenKey" -}}
{{- if .Values.auth.existingSecret -}}{{ .Values.auth.existingSecretTokenKey }}{{- else -}}admin-token{{- end -}}
{{- end -}}

{{- define "influxdb.serviceAccountName" -}}
{{- if .Values.serviceAccount.create -}}{{ default (include "quench-common.fullname" .) .Values.serviceAccount.name }}{{- else -}}{{ default "default" .Values.serviceAccount.name }}{{- end -}}
{{- end -}}

{{/* Headless service name for the StatefulSet */}}
{{- define "influxdb.headlessName" -}}
{{- printf "%s-headless" (include "quench-common.fullname" .) -}}
{{- end -}}
