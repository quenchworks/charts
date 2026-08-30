{{- define "mailpit.serviceAccountName" -}}
{{- if .Values.serviceAccount.create -}}{{ default (include "quench-common.fullname" .) .Values.serviceAccount.name }}{{- else -}}{{ default "default" .Values.serviceAccount.name }}{{- end -}}
{{- end -}}

{{/* Name of the PVC backing the message database. */}}
{{- define "mailpit.pvcName" -}}
{{- if .Values.persistence.existingClaim -}}{{ .Values.persistence.existingClaim }}{{- else -}}{{ printf "%s-data" (include "quench-common.fullname" .) }}{{- end -}}
{{- end -}}

{{/* Whether web UI / API basic auth is configured. */}}
{{- define "mailpit.authEnabled" -}}
{{- if or .Values.auth.existingSecret .Values.auth.username -}}true{{- end -}}
{{- end -}}

{{/* Secret + key holding the MP_UI_AUTH "user:password" string. */}}
{{- define "mailpit.authSecretName" -}}
{{- if .Values.auth.existingSecret -}}{{ .Values.auth.existingSecret }}{{- else -}}{{ include "quench-common.fullname" . }}{{- end -}}
{{- end -}}

{{- define "mailpit.authSecretKey" -}}
{{- if .Values.auth.existingSecret -}}{{ .Values.auth.existingSecretKey }}{{- else -}}ui-auth{{- end -}}
{{- end -}}
