{{- define "orientdb.secretName" -}}
{{- if .Values.auth.existingSecret -}}{{ .Values.auth.existingSecret }}{{- else -}}{{ include "quench-common.fullname" . }}{{- end -}}
{{- end -}}

{{- define "orientdb.secretKey" -}}
{{- if .Values.auth.existingSecret -}}{{ .Values.auth.existingSecretPasswordKey }}{{- else -}}root-password{{- end -}}
{{- end -}}

{{- define "orientdb.serviceAccountName" -}}
{{- if .Values.serviceAccount.create -}}{{ default (include "quench-common.fullname" .) .Values.serviceAccount.name }}{{- else -}}{{ default "default" .Values.serviceAccount.name }}{{- end -}}
{{- end -}}

{{- define "orientdb.headlessName" -}}
{{- printf "%s-headless" (include "quench-common.fullname" .) -}}
{{- end -}}
