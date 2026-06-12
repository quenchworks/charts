{{- define "ferretdb.serviceAccountName" -}}
{{- if .Values.serviceAccount.create -}}{{ default (include "quench-common.fullname" .) .Values.serviceAccount.name }}{{- else -}}{{ default "default" .Values.serviceAccount.name }}{{- end -}}
{{- end -}}

{{/* Secret holding the backend connection URL, and its key. */}}
{{- define "ferretdb.backendSecretName" -}}
{{- if .Values.backend.existingSecret -}}{{ .Values.backend.existingSecret }}{{- else -}}{{ printf "%s-backend" (include "quench-common.fullname" .) }}{{- end -}}
{{- end -}}

{{- define "ferretdb.backendSecretUrlKey" -}}
{{- if .Values.backend.existingSecret -}}{{ .Values.backend.existingSecretUrlKey }}{{- else -}}postgresql-url{{- end -}}
{{- end -}}
