{{- define "nginx.serviceAccountName" -}}
{{- if .Values.serviceAccount.create -}}{{ default (include "quench-common.fullname" .) .Values.serviceAccount.name }}{{- else -}}{{ default "default" .Values.serviceAccount.name }}{{- end -}}
{{- end -}}

{{/* Name of the ConfigMap holding the inline server block. */}}
{{- define "nginx.configMapName" -}}
{{- printf "%s-config" (include "quench-common.fullname" .) -}}
{{- end -}}

{{/* Resolve which ConfigMap (if any) to mount at /etc/nginx/conf.d. An external
     ConfigMap wins; otherwise the inline serverBlock ConfigMap is used when set. */}}
{{- define "nginx.mountedConfigMap" -}}
{{- if .Values.config.extraConfigMap -}}{{ .Values.config.extraConfigMap }}{{- else if .Values.config.serverBlock -}}{{ include "nginx.configMapName" . }}{{- end -}}
{{- end -}}
