{{- define "emqx.serviceAccountName" -}}
{{- if .Values.serviceAccount.create -}}{{ default (include "quench-common.fullname" .) .Values.serviceAccount.name }}{{- else -}}{{ default "default" .Values.serviceAccount.name }}{{- end -}}
{{- end -}}

{{/* Headless service name backing the StatefulSet (stable network identity). */}}
{{- define "emqx.headlessName" -}}
{{- printf "%s-headless" (include "quench-common.fullname" .) -}}
{{- end -}}

{{/* Name of the chart-managed Secret holding the dashboard password (only used
     when existingSecret is not set). */}}
{{- define "emqx.secretName" -}}
{{- if .Values.existingSecret -}}{{ .Values.existingSecret }}{{- else -}}{{ printf "%s-dashboard" (include "quench-common.fullname" .) }}{{- end -}}
{{- end -}}

{{/* Secret key the dashboard password is read from. */}}
{{- define "emqx.secretPasswordKey" -}}
{{- if .Values.existingSecret -}}{{ .Values.existingSecretPasswordKey }}{{- else -}}dashboard-password{{- end -}}
{{- end -}}
