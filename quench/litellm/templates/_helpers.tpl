{{- define "litellm.serviceAccountName" -}}
{{- if .Values.serviceAccount.create -}}{{ default (include "quench-common.fullname" .) .Values.serviceAccount.name }}{{- else -}}{{ default "default" .Values.serviceAccount.name }}{{- end -}}
{{- end -}}

{{/* Secret holding the proxy master key: an existing one, or the chart's own. */}}
{{- define "litellm.masterKeySecret" -}}
{{- if .Values.masterKey.existingSecret -}}{{ .Values.masterKey.existingSecret }}{{- else -}}{{ printf "%s-master-key" (include "quench-common.fullname" .) }}{{- end -}}
{{- end -}}

{{- define "litellm.masterKeySecretKey" -}}
{{- if .Values.masterKey.existingSecret -}}{{ .Values.masterKey.existingSecretKey }}{{- else -}}master-key{{- end -}}
{{- end -}}
