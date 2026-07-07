{{- define "descheduler.serviceAccountName" -}}
{{- if .Values.serviceAccount.create -}}{{ default (include "quench-common.fullname" .) .Values.serviceAccount.name }}{{- else -}}{{ default "default" .Values.serviceAccount.name }}{{- end -}}
{{- end -}}

{{/* Name of the ConfigMap holding the DeschedulerPolicy. */}}
{{- define "descheduler.configMapName" -}}
{{- printf "%s-policy" (include "quench-common.fullname" .) -}}
{{- end -}}

{{/* Which ConfigMap to mount at /policy: an external one wins, else the
     chart-rendered policy ConfigMap. */}}
{{- define "descheduler.mountedConfigMap" -}}
{{- if .Values.policy.existingConfigMap -}}{{ .Values.policy.existingConfigMap }}{{- else -}}{{ include "descheduler.configMapName" . }}{{- end -}}
{{- end -}}
