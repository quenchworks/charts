{{- define "qdrant.serviceAccountName" -}}
{{- if .Values.serviceAccount.create -}}{{ default (include "quench-common.fullname" .) .Values.serviceAccount.name }}{{- else -}}{{ default "default" .Values.serviceAccount.name }}{{- end -}}
{{- end -}}

{{/* Headless service used for stable peer DNS (and the per-pod address probes use). */}}
{{- define "qdrant.headlessName" -}}
{{- printf "%s-headless" (include "quench-common.fullname" .) -}}
{{- end -}}

{{/* Name of the ConfigMap holding the optional production.yaml. */}}
{{- define "qdrant.configMapName" -}}
{{- printf "%s-config" (include "quench-common.fullname" .) -}}
{{- end -}}

{{/* Name of the Secret holding the API key (when created by the chart). */}}
{{- define "qdrant.secretName" -}}
{{- printf "%s-apikey" (include "quench-common.fullname" .) -}}
{{- end -}}

{{/* Whether API-key auth is in play (inline key OR an existing Secret). */}}
{{- define "qdrant.apiKeyEnabled" -}}
{{- if or .Values.auth.apiKey .Values.auth.existingSecret -}}true{{- end -}}
{{- end -}}
