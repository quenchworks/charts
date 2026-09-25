{{- define "akhq.serviceAccountName" -}}
{{- if .Values.serviceAccount.create -}}{{ default (include "quench-common.fullname" .) .Values.serviceAccount.name }}{{- else -}}{{ default "default" .Values.serviceAccount.name }}{{- end -}}
{{- end -}}

{{- define "akhq.secretName" -}}
{{- default (include "quench-common.fullname" .) .Values.existingSecret -}}
{{- end -}}

{{/* application.yml: the UI on 8080, health and metrics on 28081, the clusters and
     any other akhq settings from values. */}}
{{- define "akhq.config" -}}
{{- $akhq := merge (dict "connections" .Values.connections) (deepCopy .Values.akhqConfig) -}}
{{- $cfg := dict "micronaut" (dict "server" (dict "port" 8080)) "endpoints" (dict "all" (dict "port" 28081)) "akhq" $akhq -}}
{{- toYaml $cfg -}}
{{- end -}}
