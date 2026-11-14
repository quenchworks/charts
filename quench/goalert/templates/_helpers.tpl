{{- define "goalert.serviceAccountName" -}}
{{- if .Values.serviceAccount.create -}}{{ default (include "quench-common.fullname" .) .Values.serviceAccount.name }}{{- else -}}{{ default "default" .Values.serviceAccount.name }}{{- end -}}
{{- end -}}

{{/* Database resolution: the bundled postgresql subchart, or externalDatabase. */}}
{{- define "goalert.db.host" -}}
{{- if .Values.postgresql.enabled -}}{{ printf "%s-postgresql" .Release.Name }}{{- else -}}{{ required "externalDatabase.host is required when postgresql.enabled=false" .Values.externalDatabase.host }}{{- end -}}
{{- end -}}
{{- define "goalert.db.port" -}}
{{- if .Values.postgresql.enabled -}}5432{{- else -}}{{ .Values.externalDatabase.port }}{{- end -}}
{{- end -}}
{{- define "goalert.db.name" -}}
{{- if .Values.postgresql.enabled -}}{{ .Values.postgresql.auth.database }}{{- else -}}{{ .Values.externalDatabase.database }}{{- end -}}
{{- end -}}
{{- define "goalert.db.user" -}}
{{- if .Values.postgresql.enabled -}}{{ .Values.postgresql.auth.username }}{{- else -}}{{ .Values.externalDatabase.username }}{{- end -}}
{{- end -}}
{{/* The bundled PostgreSQL creates auth.username as its superuser, with the
     password under postgres-password in its own Secret. */}}
{{- define "goalert.db.secretName" -}}
{{- if .Values.postgresql.enabled -}}{{ printf "%s-postgresql" .Release.Name }}
{{- else if .Values.externalDatabase.existingSecret -}}{{ .Values.externalDatabase.existingSecret }}
{{- else -}}{{ include "quench-common.fullname" . }}{{- end -}}
{{- end -}}
{{- define "goalert.db.secretKey" -}}
{{- if .Values.postgresql.enabled -}}postgres-password
{{- else if .Values.externalDatabase.existingSecret -}}{{ .Values.externalDatabase.existingSecretPasswordKey }}
{{- else -}}db-password{{- end -}}
{{- end -}}

{{- define "goalert.keySecretName" -}}
{{- default (include "quench-common.fullname" .) .Values.dataEncryptionKey.existingSecret -}}
{{- end -}}
{{- define "goalert.adminSecretName" -}}
{{- default (include "quench-common.fullname" .) .Values.admin.existingSecret -}}
{{- end -}}

{{- define "goalert.publicUrl" -}}
{{- default (printf "http://%s:%v" (include "quench-common.fullname" .) .Values.service.port) .Values.publicUrl -}}
{{- end -}}

{{/* DB_PASS, then GOALERT_DB_URL built from it with $(DB_PASS): the password stays in its Secret.
     A password with URL-reserved characters must be percent-encoded in that Secret. */}}
{{- define "goalert.dbEnv" -}}
- name: DB_PASS
  valueFrom:
    secretKeyRef:
      name: {{ include "goalert.db.secretName" . }}
      key: {{ include "goalert.db.secretKey" . }}
- name: GOALERT_DB_URL
  value: {{ printf "postgres://%s:$(DB_PASS)@%s:%s/%s?sslmode=%s" (include "goalert.db.user" .) (include "goalert.db.host" .) (include "goalert.db.port" .) (include "goalert.db.name" .) .Values.externalDatabase.sslMode | quote }}
- name: GOALERT_DATA_ENCRYPTION_KEY
  valueFrom:
    secretKeyRef:
      name: {{ include "goalert.keySecretName" . }}
      key: {{ .Values.dataEncryptionKey.existingSecretKey }}
{{- end -}}
