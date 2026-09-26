{{- define "glr.serviceAccountName" -}}
{{- if .Values.serviceAccount.create -}}{{ default (include "quench-common.fullname" .) .Values.serviceAccount.name }}{{- else -}}{{ default "default" .Values.serviceAccount.name }}{{- end -}}
{{- end -}}

{{- define "glr.secretName" -}}
{{- default (printf "%s-config" (include "quench-common.fullname" .)) .Values.existingConfigSecret -}}
{{- end -}}
