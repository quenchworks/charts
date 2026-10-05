{{- define "polaris.serviceAccountName" -}}
{{- if .Values.serviceAccount.create -}}{{ default (include "quench-common.fullname" .) .Values.serviceAccount.name }}{{- else -}}{{ default "default" .Values.serviceAccount.name }}{{- end -}}
{{- end -}}

{{/* Name of the ConfigMap holding the Polaris config.yaml. */}}
{{- define "polaris.configMapName" -}}
{{- printf "%s-config" (include "quench-common.fullname" .) -}}
{{- end -}}

{{/* Whether a config is in play (inline yaml or an external ConfigMap). */}}
{{- define "polaris.hasConfig" -}}
{{- if or .Values.config.existingConfigMap .Values.config.yaml -}}true{{- end -}}
{{- end -}}

{{/* Which ConfigMap to mount at /config: an external one wins, else the
     chart-rendered config ConfigMap. */}}
{{- define "polaris.mountedConfigMap" -}}
{{- if .Values.config.existingConfigMap -}}{{ .Values.config.existingConfigMap }}{{- else -}}{{ include "polaris.configMapName" . }}{{- end -}}
{{- end -}}
