{{- define "jaeger.serviceAccountName" -}}
{{- if .Values.serviceAccount.create -}}{{ default (include "quench-common.fullname" .) .Values.serviceAccount.name }}{{- else -}}{{ default "default" .Values.serviceAccount.name }}{{- end -}}
{{- end -}}

{{/* Name of the ConfigMap holding the Jaeger v2 config.yaml. */}}
{{- define "jaeger.configMapName" -}}
{{- printf "%s-config" (include "quench-common.fullname" .) -}}
{{- end -}}

{{/* Whether a config is in play (inline yaml or an external ConfigMap). */}}
{{- define "jaeger.hasConfig" -}}
{{- if or .Values.config.existingConfigMap .Values.config.yaml -}}true{{- end -}}
{{- end -}}

{{/* Which ConfigMap to mount at /etc/jaeger: an external one wins, else the
     chart-rendered config ConfigMap. */}}
{{- define "jaeger.mountedConfigMap" -}}
{{- if .Values.config.existingConfigMap -}}{{ .Values.config.existingConfigMap }}{{- else -}}{{ include "jaeger.configMapName" . }}{{- end -}}
{{- end -}}
