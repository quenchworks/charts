{{/* Every port the server listens on, as {name, port, servicePort, protocol}: container, Service and NetworkPolicy. */}}
{{- define "leantime.ports" -}}
{{- toJson (list (dict "name" "http" "port" 8080 "servicePort" (int .Values.service.port) "protocol" "TCP")) -}}
{{- end -}}

{{- define "leantime.secretName" -}}
{{- .Values.secret.existingSecret | default (include "quench-common.fullname" .) -}}
{{- end -}}

{{/* Leantime settings (LEAN_*). The database is the bundled PostgreSQL (its superuser password under postgres-password)
     or externalDatabase. The admin is created by the image's init (bin/leantime db:migrate) on the first install only. */}}
{{- define "leantime.env" -}}
- { name: LEAN_APP_URL, value: {{ required "appUrl is required: the public URL Leantime is served at" .Values.appUrl | quote }} }
- name: LEAN_SESSION_PASSWORD
  valueFrom:
    secretKeyRef: { name: {{ include "leantime.secretName" . }}, key: session-password }
- { name: LEAN_ADMIN_EMAIL, value: {{ required "admin.email is required" .Values.admin.email | quote }} }
- name: LEAN_ADMIN_PASSWORD
  valueFrom:
    secretKeyRef: { name: {{ include "leantime.secretName" . }}, key: admin-password }
{{- if .Values.postgresql.enabled }}
- { name: LEAN_DB_DEFAULT_CONNECTION, value: pgsql }
- { name: LEAN_DB_HOST, value: {{ printf "%s-postgresql" .Release.Name | quote }} }
- { name: LEAN_DB_PORT, value: "5432" }
- { name: LEAN_DB_DATABASE, value: {{ .Values.postgresql.auth.database | quote }} }
- { name: LEAN_DB_USER, value: {{ .Values.postgresql.auth.username | quote }} }
- name: LEAN_DB_PASSWORD
  valueFrom:
    secretKeyRef: { name: {{ printf "%s-postgresql" .Release.Name }}, key: postgres-password }
{{- else }}
- { name: LEAN_DB_DEFAULT_CONNECTION, value: {{ .Values.externalDatabase.connection | quote }} }
- { name: LEAN_DB_HOST, value: {{ required "externalDatabase.host is required when postgresql.enabled=false" .Values.externalDatabase.host | quote }} }
- { name: LEAN_DB_PORT, value: {{ .Values.externalDatabase.port | quote }} }
- { name: LEAN_DB_DATABASE, value: {{ .Values.externalDatabase.database | quote }} }
- { name: LEAN_DB_USER, value: {{ .Values.externalDatabase.username | quote }} }
- name: LEAN_DB_PASSWORD
  valueFrom:
    secretKeyRef: { name: {{ required "externalDatabase.existingSecret is required" .Values.externalDatabase.existingSecret }}, key: {{ .Values.externalDatabase.existingSecretPasswordKey }} }
{{- end }}
{{- range $k, $v := .Values.settings }}
- { name: {{ $k }}, value: {{ $v | quote }} }
{{- end }}
{{- end -}}
