{{- define "mongo-express.serviceAccountName" -}}
{{- if .Values.serviceAccount.create -}}{{ default (include "quench-common.fullname" .) .Values.serviceAccount.name }}{{- else -}}{{ default "default" .Values.serviceAccount.name }}{{- end -}}
{{- end -}}

{{/* The connection URL carries the password, so it always comes from a Secret: the
     user's existingSecret, or the managed one holding mongodb.url. */}}
{{- define "mongo-express.url.secretName" -}}
{{- if .Values.mongodb.existingSecret -}}{{ .Values.mongodb.existingSecret }}{{- else -}}{{ include "quench-common.fullname" . }}{{- end -}}
{{- end -}}

{{- define "mongo-express.url.secretKey" -}}
{{- if .Values.mongodb.existingSecret -}}{{ .Values.mongodb.existingSecretUrlKey }}{{- else -}}mongodb-url{{- end -}}
{{- end -}}

{{- define "mongo-express.auth.secretName" -}}
{{- .Values.basicAuth.existingSecret | default (include "quench-common.fullname" .) -}}
{{- end -}}

{{- define "mongo-express.auth.secretKey" -}}
{{- if .Values.basicAuth.existingSecret -}}{{ .Values.basicAuth.existingSecretPasswordKey }}{{- else -}}basic-auth-password{{- end -}}
{{- end -}}
