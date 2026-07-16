{{- define "n8n.serviceAccountName" -}}
{{- if .Values.serviceAccount.create -}}{{ default (include "quench-common.fullname" .) .Values.serviceAccount.name }}{{- else -}}{{ default "default" .Values.serviceAccount.name }}{{- end -}}
{{- end -}}

{{/* Headless service backing the StatefulSet (stable pod DNS). */}}
{{- define "n8n.headlessName" -}}
{{- printf "%s-headless" (include "quench-common.fullname" .) -}}
{{- end -}}

{{/* Managed Secret holding the encryption key (+ db-password / runner auth token). */}}
{{- define "n8n.secretName" -}}
{{- include "quench-common.fullname" . -}}
{{- end -}}

{{/* Where the encryption key lives, and under which key. */}}
{{- define "n8n.encryptionSecretName" -}}
{{- if .Values.n8n.existingSecret -}}{{ .Values.n8n.existingSecret }}{{- else -}}{{ include "n8n.secretName" . }}{{- end -}}
{{- end -}}

{{- define "n8n.encryptionSecretKey" -}}
{{- if .Values.n8n.existingSecret -}}{{ .Values.n8n.existingSecretKey }}{{- else -}}encryption-key{{- end -}}
{{- end -}}

{{/* Name of the Secret that holds the external-DB password, and the key within it. */}}
{{- define "n8n.db.secretName" -}}
{{- if .Values.database.postgresql.existingSecret -}}{{ .Values.database.postgresql.existingSecret }}{{- else -}}{{ include "n8n.secretName" . }}{{- end -}}
{{- end -}}

{{- define "n8n.db.secretPasswordKey" -}}
{{- if .Values.database.postgresql.existingSecret -}}{{ .Values.database.postgresql.existingSecretPasswordKey }}{{- else -}}db-password{{- end -}}
{{- end -}}
