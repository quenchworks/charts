{{- define "livekit.serviceAccountName" -}}
{{- if .Values.serviceAccount.create -}}{{ default (include "quench-common.fullname" .) .Values.serviceAccount.name }}{{- else -}}{{ default "default" .Values.serviceAccount.name }}{{- end -}}
{{- end -}}

{{/* Name of the ConfigMap holding the LiveKit config.yaml. */}}
{{- define "livekit.configMapName" -}}
{{- printf "%s-config" (include "quench-common.fullname" .) -}}
{{- end -}}

{{/* Which ConfigMap to mount at /config: an external one wins, else the
     chart-rendered config ConfigMap. LiveKit always needs a config. */}}
{{- define "livekit.mountedConfigMap" -}}
{{- if .Values.config.existingConfigMap -}}{{ .Values.config.existingConfigMap }}{{- else -}}{{ include "livekit.configMapName" . }}{{- end -}}
{{- end -}}
