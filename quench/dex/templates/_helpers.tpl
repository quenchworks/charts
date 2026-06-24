{{- define "dex.serviceAccountName" -}}
{{- if .Values.serviceAccount.create -}}{{ default (include "quench-common.fullname" .) .Values.serviceAccount.name }}{{- else -}}{{ default "default" .Values.serviceAccount.name }}{{- end -}}
{{- end -}}

{{/* Name of the ConfigMap holding the dex config.yaml. */}}
{{- define "dex.configMapName" -}}
{{- printf "%s-config" (include "quench-common.fullname" .) -}}
{{- end -}}

{{/* Which ConfigMap to mount as the dex config: an external one wins, else the
     chart-rendered config ConfigMap. */}}
{{- define "dex.mountedConfigMap" -}}
{{- if .Values.config.existingConfigMap -}}{{ .Values.config.existingConfigMap }}{{- else -}}{{ include "dex.configMapName" . }}{{- end -}}
{{- end -}}

{{/* Directory portion of the config mount path (the volume is mounted here and
     the config.yaml key lands at configMountPath). */}}
{{- define "dex.configMountDir" -}}
{{- .Values.configMountPath | dir -}}
{{- end -}}

{{/* File name portion of the config mount path (the ConfigMap key / subPath). */}}
{{- define "dex.configFileName" -}}
{{- .Values.configMountPath | base -}}
{{- end -}}
