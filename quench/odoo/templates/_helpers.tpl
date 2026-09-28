{{- define "odoo.serviceAccountName" -}}
{{- if .Values.serviceAccount.create -}}{{ default (include "quench-common.fullname" .) .Values.serviceAccount.name }}{{- else -}}{{ default "default" .Values.serviceAccount.name }}{{- end -}}
{{- end -}}

{{/* Database resolution: the bundled postgresql subchart, or externalDatabase. */}}
{{- define "odoo.db.host" -}}
{{- if .Values.postgresql.enabled -}}{{ printf "%s-postgresql" .Release.Name }}{{- else -}}{{ required "externalDatabase.host is required when postgresql.enabled=false" .Values.externalDatabase.host }}{{- end -}}
{{- end -}}
{{- define "odoo.db.port" -}}
{{- if .Values.postgresql.enabled -}}5432{{- else -}}{{ .Values.externalDatabase.port }}{{- end -}}
{{- end -}}
{{- define "odoo.db.name" -}}
{{- if .Values.postgresql.enabled -}}{{ .Values.postgresql.auth.database }}{{- else -}}{{ .Values.externalDatabase.database }}{{- end -}}
{{- end -}}
{{- define "odoo.db.user" -}}
{{- if .Values.postgresql.enabled -}}{{ .Values.postgresql.auth.username }}{{- else -}}{{ .Values.externalDatabase.username }}{{- end -}}
{{- end -}}
{{/* The bundled PostgreSQL creates auth.username as its superuser, with the
     password under postgres-password in its own Secret. */}}
{{- define "odoo.db.secretName" -}}
{{- if .Values.postgresql.enabled -}}{{ printf "%s-postgresql" .Release.Name }}
{{- else if .Values.externalDatabase.existingSecret -}}{{ .Values.externalDatabase.existingSecret }}
{{- else -}}{{ include "quench-common.fullname" . }}{{- end -}}
{{- end -}}
{{- define "odoo.db.secretKey" -}}
{{- if .Values.postgresql.enabled -}}postgres-password
{{- else if .Values.externalDatabase.existingSecret -}}{{ .Values.externalDatabase.existingSecretPasswordKey }}
{{- else -}}db-password{{- end -}}
{{- end -}}

{{- define "odoo.adminSecretName" -}}
{{- default (include "quench-common.fullname" .) .Values.adminPassword.existingSecret -}}
{{- end -}}

{{/* Server flags shared by the init container and the server. The password comes
     from PGPASSWORD, which libpq reads when Odoo's db_password is unset. */}}
{{- define "odoo.args" -}}
- --data-dir=/data
- --db_host={{ include "odoo.db.host" . }}
- --db_port={{ include "odoo.db.port" . }}
- --db_user={{ include "odoo.db.user" . }}
- --database={{ include "odoo.db.name" . }}
- --db-filter=^{{ include "odoo.db.name" . }}$
- --no-database-list
{{- end -}}

{{- define "odoo.env" -}}
- { name: ODOO_DB, value: {{ include "odoo.db.name" . | quote }} }
- { name: ODOO_DB_HOST, value: {{ include "odoo.db.host" . | quote }} }
- { name: ODOO_DB_PORT, value: {{ include "odoo.db.port" . | quote }} }
- { name: ODOO_DB_USER, value: {{ include "odoo.db.user" . | quote }} }
- name: PGPASSWORD
  valueFrom:
    secretKeyRef:
      name: {{ include "odoo.db.secretName" . }}
      key: {{ include "odoo.db.secretKey" . }}
{{- end -}}
