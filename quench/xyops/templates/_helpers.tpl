{{- define "xyops.serviceAccountName" -}}
{{- if .Values.serviceAccount.create -}}{{ default (include "quench-common.fullname" .) .Values.serviceAccount.name }}{{- else -}}{{ default "default" .Values.serviceAccount.name }}{{- end -}}
{{- end -}}

{{/* Headless service name backing the StatefulSet (stable network identity). */}}
{{- define "xyops.headlessName" -}}
{{- printf "%s-headless" (include "quench-common.fullname" .) -}}
{{- end -}}

{{/* Name of the Secret holding XYOPS_secret_key: the user-supplied existingSecret,
     else the chart-managed Secret named after the release. */}}
{{- define "xyops.secretName" -}}
{{- if .Values.auth.existingSecret -}}{{ .Values.auth.existingSecret }}{{- else -}}{{ include "quench-common.fullname" . }}{{- end -}}
{{- end -}}

{{/* Key within the Secret that holds the secret_key value. */}}
{{- define "xyops.secretKeyName" -}}
{{- if .Values.auth.existingSecret -}}{{ .Values.auth.existingSecretKey }}{{- else -}}secret-key{{- end -}}
{{- end -}}
