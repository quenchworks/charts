{{- define "rabbitmq.secretName" -}}
{{- if .Values.auth.existingSecret -}}{{ .Values.auth.existingSecret }}{{- else -}}{{ include "quench-common.fullname" . }}{{- end -}}
{{- end -}}

{{- define "rabbitmq.passwordKey" -}}
{{- if .Values.auth.existingSecret -}}{{ .Values.auth.existingSecretPasswordKey }}{{- else -}}rabbitmq-password{{- end -}}
{{- end -}}

{{- define "rabbitmq.erlangCookieKey" -}}
{{- if .Values.auth.existingSecret -}}{{ .Values.auth.existingSecretErlangCookieKey }}{{- else -}}rabbitmq-erlang-cookie{{- end -}}
{{- end -}}

{{- define "rabbitmq.serviceAccountName" -}}
{{- if .Values.serviceAccount.create -}}{{ default (include "quench-common.fullname" .) .Values.serviceAccount.name }}{{- else -}}{{ default "default" .Values.serviceAccount.name }}{{- end -}}
{{- end -}}

{{- define "rabbitmq.headlessName" -}}
{{- printf "%s-headless" (include "quench-common.fullname" .) -}}
{{- end -}}
