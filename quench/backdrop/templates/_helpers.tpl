{{- define "backdrop.serviceAccountName" -}}
{{- if .Values.serviceAccount.create -}}{{ default (include "quench-common.fullname" .) .Values.serviceAccount.name }}{{- else -}}{{ default "default" .Values.serviceAccount.name }}{{- end -}}
{{- end -}}

{{/*
Database wiring. The bundled subchart's Service and Secret are both "<release>-mysql"
(its quench-common.fullname resolves against its own chart name), unless
mysql.auth.existingSecret names another Secret.
*/}}
{{- define "backdrop.db.host" -}}
{{- if .Values.mysql.enabled -}}
{{- printf "%s-mysql" .Release.Name -}}
{{- else -}}
{{- required "externalDatabase.host is required when mysql.enabled=false" .Values.externalDatabase.host -}}
{{- end -}}
{{- end -}}

{{- define "backdrop.db.port" -}}
{{- if .Values.mysql.enabled -}}3306{{- else -}}{{ .Values.externalDatabase.port }}{{- end -}}
{{- end -}}

{{- define "backdrop.db.name" -}}
{{- if .Values.mysql.enabled -}}{{ required "mysql.auth.database is required" .Values.mysql.auth.database }}{{- else -}}{{ .Values.externalDatabase.database }}{{- end -}}
{{- end -}}

{{- define "backdrop.db.user" -}}
{{- if .Values.mysql.enabled -}}{{ required "mysql.auth.username is required" .Values.mysql.auth.username }}{{- else -}}{{ .Values.externalDatabase.user }}{{- end -}}
{{- end -}}

{{- define "backdrop.db.secretName" -}}
{{- if .Values.mysql.enabled -}}
{{- .Values.mysql.auth.existingSecret | default (printf "%s-mysql" .Release.Name) -}}
{{- else if .Values.externalDatabase.existingSecret -}}
{{- .Values.externalDatabase.existingSecret -}}
{{- else -}}
{{- include "quench-common.fullname" . -}}
{{- end -}}
{{- end -}}

{{- define "backdrop.db.secretKey" -}}
{{- if .Values.mysql.enabled -}}
{{- if .Values.mysql.auth.existingSecret -}}{{ .Values.mysql.auth.existingSecretPasswordKey | default "mysql-password" }}{{- else -}}mysql-password{{- end -}}
{{- else if .Values.externalDatabase.existingSecret -}}
{{- .Values.externalDatabase.existingSecretPasswordKey -}}
{{- else -}}
db-password
{{- end -}}
{{- end -}}

{{- define "backdrop.admin.secretName" -}}
{{- .Values.backdrop.admin.existingSecret | default (include "quench-common.fullname" .) -}}
{{- end -}}

{{- define "backdrop.admin.secretKey" -}}
{{- if .Values.backdrop.admin.existingSecret -}}{{ .Values.backdrop.admin.existingSecretPasswordKey }}{{- else -}}admin-password{{- end -}}
{{- end -}}

{{/* The env both containers share: settings.php reads these. */}}
{{- define "backdrop.dbEnv" -}}
- name: BACKDROP_DB_HOST
  value: {{ include "backdrop.db.host" . | quote }}
- name: BACKDROP_DB_PORT
  value: {{ include "backdrop.db.port" . | quote }}
- name: BACKDROP_DB_NAME
  value: {{ include "backdrop.db.name" . | quote }}
- name: BACKDROP_DB_USER
  value: {{ include "backdrop.db.user" . | quote }}
- name: BACKDROP_DB_PREFIX
  value: {{ .Values.database.prefix | quote }}
- name: BACKDROP_DB_PASSWORD
  valueFrom:
    secretKeyRef:
      name: {{ include "backdrop.db.secretName" . }}
      key: {{ include "backdrop.db.secretKey" . }}
- name: BACKDROP_HASH_SALT
  valueFrom:
    secretKeyRef:
      name: {{ include "quench-common.fullname" . }}
      key: hash-salt
{{- end -}}
