{{/* Secret holding the S3 access key + secret key + rpc secret + admin token */}}
{{- define "garage.secretName" -}}
{{- if .Values.auth.existingSecret -}}{{ .Values.auth.existingSecret }}{{- else -}}{{ include "quench-common.fullname" . }}{{- end -}}
{{- end -}}

{{- define "garage.secretAccessKeyKey" -}}
{{- if .Values.auth.existingSecret -}}{{ .Values.auth.existingSecretAccessKeyKey }}{{- else -}}access-key{{- end -}}
{{- end -}}

{{- define "garage.secretSecretKeyKey" -}}
{{- if .Values.auth.existingSecret -}}{{ .Values.auth.existingSecretSecretKeyKey }}{{- else -}}secret-key{{- end -}}
{{- end -}}

{{- define "garage.secretRpcSecretKey" -}}
{{- if .Values.auth.existingSecret -}}{{ .Values.auth.existingSecretRpcSecretKey }}{{- else -}}rpc-secret{{- end -}}
{{- end -}}

{{- define "garage.secretAdminTokenKey" -}}
{{- if .Values.auth.existingSecret -}}{{ .Values.auth.existingSecretAdminTokenKey }}{{- else -}}admin-token{{- end -}}
{{- end -}}

{{- define "garage.serviceAccountName" -}}
{{- if .Values.serviceAccount.create -}}{{ default (include "quench-common.fullname" .) .Values.serviceAccount.name }}{{- else -}}{{ default "default" .Values.serviceAccount.name }}{{- end -}}
{{- end -}}

{{/* Headless service name for the StatefulSet */}}
{{- define "garage.headlessName" -}}
{{- printf "%s-headless" (include "quench-common.fullname" .) -}}
{{- end -}}
