{{- define "opa.serviceAccountName" -}}
{{- if .Values.serviceAccount.create -}}{{ default (include "quench-common.fullname" .) .Values.serviceAccount.name }}{{- else -}}{{ default "default" .Values.serviceAccount.name }}{{- end -}}
{{- end -}}

{{/* Name of the ConfigMap holding the OPA config.yaml. */}}
{{- define "opa.configMapName" -}}
{{- printf "%s-config" (include "quench-common.fullname" .) -}}
{{- end -}}

{{/* Whether a config is in play (inline yaml or an external ConfigMap). */}}
{{- define "opa.hasConfig" -}}
{{- if or .Values.config.existingConfigMap .Values.config.yaml -}}true{{- end -}}
{{- end -}}

{{/* Which ConfigMap to mount at /config: an external one wins, else the
     chart-rendered config ConfigMap. */}}
{{- define "opa.mountedConfigMap" -}}
{{- if .Values.config.existingConfigMap -}}{{ .Values.config.existingConfigMap }}{{- else -}}{{ include "opa.configMapName" . }}{{- end -}}
{{- end -}}
