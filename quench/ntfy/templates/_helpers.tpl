{{- define "ntfy.serviceAccountName" -}}
{{- if .Values.serviceAccount.create -}}{{ default (include "quench-common.fullname" .) .Values.serviceAccount.name }}{{- else -}}{{ default "default" .Values.serviceAccount.name }}{{- end -}}
{{- end -}}

{{/* Name of the ConfigMap holding the ntfy server.yml. */}}
{{- define "ntfy.configMapName" -}}
{{- printf "%s-config" (include "quench-common.fullname" .) -}}
{{- end -}}

{{/* Whether a config is in play (inline yaml or an external ConfigMap). */}}
{{- define "ntfy.hasConfig" -}}
{{- if or .Values.config.existingConfigMap .Values.config.yaml -}}true{{- end -}}
{{- end -}}

{{/* Which ConfigMap to mount at /etc/ntfy: an external one wins, else the
     chart-rendered config ConfigMap. */}}
{{- define "ntfy.mountedConfigMap" -}}
{{- if .Values.config.existingConfigMap -}}{{ .Values.config.existingConfigMap }}{{- else -}}{{ include "ntfy.configMapName" . }}{{- end -}}
{{- end -}}

{{/* Name of the PVC backing the cache/attachment dir. */}}
{{- define "ntfy.pvcName" -}}
{{- if .Values.persistence.existingClaim -}}{{ .Values.persistence.existingClaim }}{{- else -}}{{ printf "%s-cache" (include "quench-common.fullname" .) }}{{- end -}}
{{- end -}}
