{{- define "redis.secretName" -}}
{{- if .Values.auth.existingSecret -}}
{{- .Values.auth.existingSecret -}}
{{- else -}}
{{- include "quench-common.fullname" . -}}
{{- end -}}
{{- end -}}

{{- define "redis.secretPasswordKey" -}}
{{- if .Values.auth.existingSecret -}}
{{- .Values.auth.existingSecretPasswordKey -}}
{{- else -}}
redis-password
{{- end -}}
{{- end -}}
