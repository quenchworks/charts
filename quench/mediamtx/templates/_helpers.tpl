{{- define "mediamtx.serviceAccountName" -}}
{{- if .Values.serviceAccount.create -}}{{ default (include "quench-common.fullname" .) .Values.serviceAccount.name }}{{- else -}}{{ default "default" .Values.serviceAccount.name }}{{- end -}}
{{- end -}}

{{/* Name of the chart-rendered ConfigMap holding mediamtx.yml. */}}
{{- define "mediamtx.configMapName" -}}
{{- printf "%s-config" (include "quench-common.fullname" .) -}}
{{- end -}}

{{/* Whether a config file is mounted: a full user config (inline or external) or
     the minimal API-enabling snippet this chart injects when api.enabled. */}}
{{- define "mediamtx.hasConfig" -}}
{{- if or .Values.config.existingConfigMap .Values.config.yaml .Values.api.enabled -}}true{{- end -}}
{{- end -}}

{{/* Which ConfigMap to mount at /config: an external one wins, else the
     chart-rendered ConfigMap. */}}
{{- define "mediamtx.mountedConfigMap" -}}
{{- if .Values.config.existingConfigMap -}}{{ .Values.config.existingConfigMap }}{{- else -}}{{ include "mediamtx.configMapName" . }}{{- end -}}
{{- end -}}
