{{/* Every port the server listens on, as {name, port, servicePort, protocol}: container, Service and NetworkPolicy. */}}
{{- define "rallly.ports" -}}
{{- toJson (list (dict "name" "http" "port" 3000 "servicePort" (int .Values.service.port) "protocol" "TCP")) -}}
{{- end -}}

{{- define "rallly.secretName" -}}
{{- .Values.secret.existingSecret | default (include "quench-common.fullname" .) -}}
{{- end -}}

{{/* Rallly settings. The bundled PostgreSQL password comes from the postgresql subchart's own Secret and is spliced
     into DATABASE_URL by Kubernetes $(VAR) expansion; generated passwords are alphanumeric, so they are URL-safe. */}}
{{- define "rallly.env" -}}
{{- if not .Values.baseUrl }}{{ fail "set baseUrl: the public URL users open, e.g. https://polls.example.com" }}{{ end }}
{{- if not .Values.supportEmail }}{{ fail "set supportEmail: the address shown to users for help" }}{{ end }}
- { name: NEXT_PUBLIC_BASE_URL, value: {{ .Values.baseUrl | trimSuffix "/" | quote }} }
- { name: SUPPORT_EMAIL, value: {{ .Values.supportEmail | quote }} }
{{- with .Values.noreplyEmail }}
- { name: NOREPLY_EMAIL, value: {{ . | quote }} }
{{- end }}
{{- with .Values.allowedEmails }}
- { name: ALLOWED_EMAILS, value: {{ . | quote }} }
{{- end }}
- name: SECRET_PASSWORD
  valueFrom:
    secretKeyRef: { name: {{ include "rallly.secretName" . }}, key: secret-password }
{{- with .Values.smtp }}
{{- if .host }}
- { name: SMTP_HOST, value: {{ .host | quote }} }
- { name: SMTP_PORT, value: {{ .port | quote }} }
- { name: SMTP_SECURE, value: {{ .secure | quote }} }
- { name: SMTP_REJECT_UNAUTHORIZED, value: {{ .rejectUnauthorized | quote }} }
{{- if .user }}
- { name: SMTP_USER, value: {{ .user | quote }} }
- name: SMTP_PWD
  valueFrom:
    secretKeyRef: { name: {{ .existingSecret | default (include "rallly.secretName" $) }}, key: {{ .existingSecretKey }} }
{{- end }}
{{- end }}
{{- end }}
{{- if .Values.postgresql.enabled }}
- name: DB_PASSWORD
  valueFrom:
    secretKeyRef: { name: {{ printf "%s-postgresql" .Release.Name }}, key: postgres-password }
- { name: DATABASE_URL, value: "postgresql://{{ .Values.postgresql.auth.username }}:$(DB_PASSWORD)@{{ .Release.Name }}-postgresql:5432/{{ .Values.postgresql.auth.database }}" }
{{- else if .Values.externalDatabase.existingSecret }}
- name: DATABASE_URL
  valueFrom:
    secretKeyRef: { name: {{ .Values.externalDatabase.existingSecret }}, key: {{ .Values.externalDatabase.existingSecretKey }} }
{{- else }}
{{- fail "set postgresql.enabled, or externalDatabase.existingSecret with a DATABASE_URL" }}
{{- end }}
{{- range $k, $v := .Values.settings }}
- { name: {{ $k }}, value: {{ $v | quote }} }
{{- end }}
{{- end -}}
