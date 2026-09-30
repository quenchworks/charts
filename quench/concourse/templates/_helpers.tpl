{{- define "concourse.serviceAccountName" -}}
{{- if .Values.serviceAccount.create -}}{{ default (include "quench-common.fullname" .) .Values.serviceAccount.name }}{{- else -}}{{ default "default" .Values.serviceAccount.name }}{{- end -}}
{{- end -}}

{{/* Selector labels for one role (web or worker); both roles share the chart's labels. */}}
{{- define "concourse.selectorLabels" -}}
{{ include "quench-common.selectorLabels" .ctx }}
app.kubernetes.io/component: {{ .component }}
{{- end -}}

{{- define "concourse.keysSecret" -}}
{{- printf "%s-keys" (include "quench-common.fullname" .) -}}
{{- end -}}

{{- define "concourse.db.host" -}}
{{- if .Values.postgresql.enabled -}}{{ printf "%s-postgresql" .Release.Name }}{{- else -}}{{ required "externalDatabase.host is required when postgresql.enabled=false" .Values.externalDatabase.host }}{{- end -}}
{{- end -}}

{{/* The DB password Secret. With the bundled PostgreSQL it is that chart's own Secret, so
     a default install never holds two different generated passwords. */}}
{{- define "concourse.db.secretName" -}}
{{- if .Values.postgresql.enabled -}}
{{- .Values.postgresql.auth.existingSecret | default (printf "%s-postgresql" .Release.Name) -}}
{{- else -}}
{{- .Values.externalDatabase.existingSecret | default (include "quench-common.fullname" .) -}}
{{- end -}}
{{- end -}}

{{- define "concourse.db.secretKey" -}}
{{- if .Values.postgresql.enabled -}}
{{- if .Values.postgresql.auth.existingSecret -}}{{ .Values.postgresql.auth.existingSecretPasswordKey | default "postgres-password" }}{{- else -}}postgres-password{{- end -}}
{{- else if .Values.externalDatabase.existingSecret -}}
{{- .Values.externalDatabase.existingSecretPasswordKey -}}
{{- else -}}
db-password
{{- end -}}
{{- end -}}
