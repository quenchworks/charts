{{- define "listmonk.serviceAccountName" -}}
{{- if .Values.serviceAccount.create -}}{{ default (include "quench-common.fullname" .) .Values.serviceAccount.name }}{{- else -}}{{ default "default" .Values.serviceAccount.name }}{{- end -}}
{{- end -}}

{{- define "listmonk.pvcName" -}}
{{- .Values.persistence.existingClaim | default (include "quench-common.fullname" .) -}}
{{- end -}}

{{/* Database resolution: the bundled postgresql subchart, or externalDatabase. */}}
{{- define "listmonk.db.host" -}}
{{- if .Values.postgresql.enabled -}}{{ printf "%s-postgresql" .Release.Name }}{{- else -}}{{ required "externalDatabase.host is required when postgresql.enabled=false" .Values.externalDatabase.host }}{{- end -}}
{{- end -}}
{{- define "listmonk.db.port" -}}
{{- if .Values.postgresql.enabled -}}5432{{- else -}}{{ .Values.externalDatabase.port }}{{- end -}}
{{- end -}}
{{- define "listmonk.db.name" -}}
{{- if .Values.postgresql.enabled -}}{{ .Values.postgresql.auth.database }}{{- else -}}{{ .Values.externalDatabase.database }}{{- end -}}
{{- end -}}
{{- define "listmonk.db.user" -}}
{{- if .Values.postgresql.enabled -}}{{ .Values.postgresql.auth.username }}{{- else -}}{{ .Values.externalDatabase.username }}{{- end -}}
{{- end -}}
{{/* The bundled PostgreSQL creates auth.username as its superuser, with the
     password under postgres-password in its own Secret. */}}
{{- define "listmonk.db.secretName" -}}
{{- if .Values.postgresql.enabled -}}{{ printf "%s-postgresql" .Release.Name }}
{{- else if .Values.externalDatabase.existingSecret -}}{{ .Values.externalDatabase.existingSecret }}
{{- else -}}{{ include "quench-common.fullname" . }}{{- end -}}
{{- end -}}
{{- define "listmonk.db.secretKey" -}}
{{- if .Values.postgresql.enabled -}}postgres-password
{{- else if .Values.externalDatabase.existingSecret -}}{{ .Values.externalDatabase.existingSecretPasswordKey }}
{{- else -}}db-password{{- end -}}
{{- end -}}

{{- define "listmonk.adminSecretName" -}}
{{- default (include "quench-common.fullname" .) .Values.admin.existingSecret -}}
{{- end -}}

{{/* LISTMONK_db__* for the install/upgrade init containers and the server. */}}
{{- define "listmonk.dbEnv" -}}
- { name: LISTMONK_db__host, value: {{ include "listmonk.db.host" . | quote }} }
- { name: LISTMONK_db__port, value: {{ include "listmonk.db.port" . | quote }} }
- { name: LISTMONK_db__user, value: {{ include "listmonk.db.user" . | quote }} }
- { name: LISTMONK_db__database, value: {{ include "listmonk.db.name" . | quote }} }
- { name: LISTMONK_db__ssl_mode, value: {{ .Values.externalDatabase.sslMode | quote }} }
- name: LISTMONK_db__password
  valueFrom:
    secretKeyRef:
      name: {{ include "listmonk.db.secretName" . }}
      key: {{ include "listmonk.db.secretKey" . }}
{{- end -}}
