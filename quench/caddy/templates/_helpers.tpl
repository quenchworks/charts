{{- define "caddy.serviceAccountName" -}}
{{- if .Values.serviceAccount.create -}}{{ default (include "quench-common.fullname" .) .Values.serviceAccount.name }}{{- else -}}{{ default "default" .Values.serviceAccount.name }}{{- end -}}
{{- end -}}

{{/* Name of the ConfigMap holding the inline Caddyfile. */}}
{{- define "caddy.configMapName" -}}
{{- printf "%s-config" (include "quench-common.fullname" .) -}}
{{- end -}}

{{/* Resolve which ConfigMap holds the Caddyfile mounted at /etc/caddy. An
     existing ConfigMap wins; otherwise the inline caddyfile ConfigMap is used. */}}
{{- define "caddy.mountedConfigMap" -}}
{{- if .Values.config.existingConfigMap -}}{{ .Values.config.existingConfigMap }}{{- else -}}{{ include "caddy.configMapName" . }}{{- end -}}
{{- end -}}
