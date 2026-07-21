{{- define "code-server.serviceAccountName" -}}
{{- if .Values.serviceAccount.create -}}{{ default (include "quench-common.fullname" .) .Values.serviceAccount.name }}{{- else -}}{{ default "default" .Values.serviceAccount.name }}{{- end -}}
{{- end -}}

{{/* Name of the Secret holding the code-server login PASSWORD. An externally
     managed Secret wins over the chart-generated one. */}}
{{- define "code-server.secretName" -}}
{{- if .Values.auth.existingSecret -}}{{ .Values.auth.existingSecret }}{{- else -}}{{ include "quench-common.fullname" . }}{{- end -}}
{{- end -}}

{{/* Name of the PVC bound at $HOME (workspace + user data). */}}
{{- define "code-server.pvcName" -}}
{{- if .Values.persistence.existingClaim -}}{{ .Values.persistence.existingClaim }}{{- else -}}{{ printf "%s-data" (include "quench-common.fullname" .) }}{{- end -}}
{{- end -}}
