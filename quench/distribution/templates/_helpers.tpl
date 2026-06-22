{{- define "distribution.serviceAccountName" -}}
{{- if .Values.serviceAccount.create -}}{{ default (include "quench-common.fullname" .) .Values.serviceAccount.name }}{{- else -}}{{ default "default" .Values.serviceAccount.name }}{{- end -}}
{{- end -}}

{{/* Headless service name for the StatefulSet */}}
{{- define "distribution.headlessName" -}}
{{- printf "%s-headless" (include "quench-common.fullname" .) -}}
{{- end -}}

{{/* Name of the ConfigMap holding config.yml */}}
{{- define "distribution.configMapName" -}}
{{- printf "%s-config" (include "quench-common.fullname" .) -}}
{{- end -}}

{{/* Which ConfigMap to mount at /etc/distribution: an external one wins, else the
     chart-rendered config.yml ConfigMap. */}}
{{- define "distribution.mountedConfigMap" -}}
{{- if .Values.config.existingConfigMap -}}{{ .Values.config.existingConfigMap }}{{- else -}}{{ include "distribution.configMapName" . }}{{- end -}}
{{- end -}}
