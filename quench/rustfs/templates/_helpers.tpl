{{/* Secret holding the S3 access key + secret key */}}
{{- define "rustfs.secretName" -}}
{{- if .Values.auth.existingSecret -}}{{ .Values.auth.existingSecret }}{{- else -}}{{ include "quench-common.fullname" . }}{{- end -}}
{{- end -}}

{{- define "rustfs.secretAccessKeyKey" -}}
{{- if .Values.auth.existingSecret -}}{{ .Values.auth.existingSecretAccessKeyKey }}{{- else -}}access-key{{- end -}}
{{- end -}}

{{- define "rustfs.secretSecretKeyKey" -}}
{{- if .Values.auth.existingSecret -}}{{ .Values.auth.existingSecretSecretKeyKey }}{{- else -}}secret-key{{- end -}}
{{- end -}}

{{- define "rustfs.serviceAccountName" -}}
{{- if .Values.serviceAccount.create -}}{{ default (include "quench-common.fullname" .) .Values.serviceAccount.name }}{{- else -}}{{ default "default" .Values.serviceAccount.name }}{{- end -}}
{{- end -}}

{{/* Headless service name for the StatefulSet */}}
{{- define "rustfs.headlessName" -}}
{{- printf "%s-headless" (include "quench-common.fullname" .) -}}
{{- end -}}
