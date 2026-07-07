{{- define "zot.serviceAccountName" -}}
{{- if .Values.serviceAccount.create -}}{{ default (include "quench-common.fullname" .) .Values.serviceAccount.name }}{{- else -}}{{ default "default" .Values.serviceAccount.name }}{{- end -}}
{{- end -}}

{{/* Headless service name for the StatefulSet */}}
{{- define "zot.headlessName" -}}
{{- printf "%s-headless" (include "quench-common.fullname" .) -}}
{{- end -}}

{{/* Name of the ConfigMap holding config.json */}}
{{- define "zot.configMapName" -}}
{{- printf "%s-config" (include "quench-common.fullname" .) -}}
{{- end -}}

{{/* Which ConfigMap to mount at /etc/zot: an external one wins, else the
     chart-rendered config.json ConfigMap. */}}
{{- define "zot.mountedConfigMap" -}}
{{- if .Values.config.existingConfigMap -}}{{ .Values.config.existingConfigMap }}{{- else -}}{{ include "zot.configMapName" . }}{{- end -}}
{{- end -}}
