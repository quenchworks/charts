{{/* Secret holding the admin user + password */}}
{{- define "grafana.secretName" -}}
{{- if .Values.auth.existingSecret -}}{{ .Values.auth.existingSecret }}{{- else -}}{{ include "quench-common.fullname" . }}{{- end -}}
{{- end -}}

{{- define "grafana.secretUserKey" -}}
{{- if .Values.auth.existingSecret -}}{{ .Values.auth.existingSecretUserKey }}{{- else -}}admin-user{{- end -}}
{{- end -}}

{{- define "grafana.secretPasswordKey" -}}
{{- if .Values.auth.existingSecret -}}{{ .Values.auth.existingSecretPasswordKey }}{{- else -}}admin-password{{- end -}}
{{- end -}}

{{- define "grafana.serviceAccountName" -}}
{{- if .Values.serviceAccount.create -}}{{ default (include "quench-common.fullname" .) .Values.serviceAccount.name }}{{- else -}}{{ default "default" .Values.serviceAccount.name }}{{- end -}}
{{- end -}}

{{/* Headless service name for the StatefulSet */}}
{{- define "grafana.headlessName" -}}
{{- printf "%s-headless" (include "quench-common.fullname" .) -}}
{{- end -}}

{{/* ConfigMap holding provisioned datasources */}}
{{- define "grafana.datasourcesConfigMapName" -}}
{{- printf "%s-datasources" (include "quench-common.fullname" .) -}}
{{- end -}}
