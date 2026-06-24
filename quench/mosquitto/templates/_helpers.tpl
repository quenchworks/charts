{{- define "mosquitto.serviceAccountName" -}}
{{- if .Values.serviceAccount.create -}}{{ default (include "quench-common.fullname" .) .Values.serviceAccount.name }}{{- else -}}{{ default "default" .Values.serviceAccount.name }}{{- end -}}
{{- end -}}

{{/* Name of the ConfigMap holding mosquitto.conf. */}}
{{- define "mosquitto.configMapName" -}}
{{- printf "%s-config" (include "quench-common.fullname" .) -}}
{{- end -}}

{{/* Which ConfigMap to mount as mosquitto.conf: an external one wins, else the
     chart-rendered config ConfigMap. */}}
{{- define "mosquitto.mountedConfigMap" -}}
{{- if .Values.config.existingConfigMap -}}{{ .Values.config.existingConfigMap }}{{- else -}}{{ include "mosquitto.configMapName" . }}{{- end -}}
{{- end -}}
