{{- define "cloudflared.secretName" -}}
{{- if .Values.tunnel.existingSecret -}}{{ .Values.tunnel.existingSecret }}{{- else -}}{{ include "quench-common.fullname" . }}{{- end -}}
{{- end -}}
