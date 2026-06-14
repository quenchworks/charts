{{- define "meilisearch.serviceAccountName" -}}
{{- if .Values.serviceAccount.create -}}{{ default (include "quench-common.fullname" .) .Values.serviceAccount.name }}{{- else -}}{{ default "default" .Values.serviceAccount.name }}{{- end -}}
{{- end -}}

{{/* Headless service for the StatefulSet's stable per-pod DNS. */}}
{{- define "meilisearch.headlessName" -}}
{{- printf "%s-headless" (include "quench-common.fullname" .) -}}
{{- end -}}

{{/* Name of the chart-managed Secret holding the master key. */}}
{{- define "meilisearch.secretName" -}}
{{- printf "%s-masterkey" (include "quench-common.fullname" .) -}}
{{- end -}}

{{/* The Secret name the workload reads the master key from: the user's existingSecret
     if set, otherwise the chart-managed one. */}}
{{- define "meilisearch.secretRefName" -}}
{{- if .Values.auth.existingSecret -}}{{ .Values.auth.existingSecret }}{{- else -}}{{ include "meilisearch.secretName" . }}{{- end -}}
{{- end -}}

{{/* The key within that Secret. existingSecretKey for a user Secret, master-key for ours. */}}
{{- define "meilisearch.secretRefKey" -}}
{{- if .Values.auth.existingSecret -}}{{ .Values.auth.existingSecretKey }}{{- else -}}master-key{{- end -}}
{{- end -}}
