{{- define "redmine.serviceAccountName" -}}
{{- if .Values.serviceAccount.create -}}{{ default (include "quench-common.fullname" .) .Values.serviceAccount.name }}{{- else -}}{{ default "default" .Values.serviceAccount.name }}{{- end -}}
{{- end -}}

{{/* Database resolution: the bundled postgresql subchart, or externalDatabase. */}}
{{- define "redmine.db.host" -}}
{{- if .Values.postgresql.enabled -}}{{ printf "%s-postgresql" .Release.Name }}{{- else -}}{{ required "externalDatabase.host is required when postgresql.enabled=false" .Values.externalDatabase.host }}{{- end -}}
{{- end -}}
{{- define "redmine.db.port" -}}
{{- if .Values.postgresql.enabled -}}5432{{- else -}}{{ .Values.externalDatabase.port }}{{- end -}}
{{- end -}}
{{- define "redmine.db.name" -}}
{{- if .Values.postgresql.enabled -}}{{ .Values.postgresql.auth.database }}{{- else -}}{{ .Values.externalDatabase.database }}{{- end -}}
{{- end -}}
{{- define "redmine.db.user" -}}
{{- if .Values.postgresql.enabled -}}{{ .Values.postgresql.auth.username }}{{- else -}}{{ .Values.externalDatabase.username }}{{- end -}}
{{- end -}}
{{/* The bundled PostgreSQL creates auth.username as its superuser, with the
     password under postgres-password in its own Secret. */}}
{{- define "redmine.db.secretName" -}}
{{- if .Values.postgresql.enabled -}}{{ printf "%s-postgresql" .Release.Name }}
{{- else if .Values.externalDatabase.existingSecret -}}{{ .Values.externalDatabase.existingSecret }}
{{- else -}}{{ include "quench-common.fullname" . }}{{- end -}}
{{- end -}}
{{- define "redmine.db.secretKey" -}}
{{- if .Values.postgresql.enabled -}}postgres-password
{{- else if .Values.externalDatabase.existingSecret -}}{{ .Values.externalDatabase.existingSecretPasswordKey }}
{{- else -}}db-password{{- end -}}
{{- end -}}

{{- define "redmine.adminSecretName" -}}
{{- default (include "quench-common.fullname" .) .Values.adminPassword.existingSecret -}}
{{- end -}}
{{- define "redmine.keySecretName" -}}
{{- default (include "quench-common.fullname" .) .Values.secretKeyBase.existingSecret -}}
{{- end -}}

{{/* Environment shared by the init container and the server. */}}
{{- define "redmine.env" -}}
- { name: REDMINE_DB_HOST, value: {{ include "redmine.db.host" . | quote }} }
- { name: REDMINE_DB_PORT, value: {{ include "redmine.db.port" . | quote }} }
- { name: REDMINE_DB_NAME, value: {{ include "redmine.db.name" . | quote }} }
- { name: REDMINE_DB_USER, value: {{ include "redmine.db.user" . | quote }} }
- name: REDMINE_DB_PASSWORD
  valueFrom:
    secretKeyRef:
      name: {{ include "redmine.db.secretName" . }}
      key: {{ include "redmine.db.secretKey" . }}
- name: SECRET_KEY_BASE
  valueFrom:
    secretKeyRef:
      name: {{ include "redmine.keySecretName" . }}
      key: {{ .Values.secretKeyBase.existingSecretKey }}
{{- end -}}
