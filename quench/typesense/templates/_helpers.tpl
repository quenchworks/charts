{{- define "typesense.serviceAccountName" -}}
{{- if .Values.serviceAccount.create -}}{{ default (include "quench-common.fullname" .) .Values.serviceAccount.name }}{{- else -}}{{ default "default" .Values.serviceAccount.name }}{{- end -}}
{{- end -}}

{{/* Headless service for the StatefulSet's stable per-pod DNS. */}}
{{- define "typesense.headlessName" -}}
{{- printf "%s-headless" (include "quench-common.fullname" .) -}}
{{- end -}}

{{/* Name of the chart-managed Secret holding the API key. */}}
{{- define "typesense.secretName" -}}
{{- printf "%s-apikey" (include "quench-common.fullname" .) -}}
{{- end -}}

{{/* The Secret name the workload reads the API key from: the user's existingSecret
     if set, otherwise the chart-managed one. */}}
{{- define "typesense.secretRefName" -}}
{{- if .Values.auth.existingSecret -}}{{ .Values.auth.existingSecret }}{{- else -}}{{ include "typesense.secretName" . }}{{- end -}}
{{- end -}}

{{/* The key within that Secret. existingSecretKey for a user Secret, api-key for ours. */}}
{{- define "typesense.secretRefKey" -}}
{{- if .Values.auth.existingSecret -}}{{ .Values.auth.existingSecretKey }}{{- else -}}api-key{{- end -}}
{{- end -}}
