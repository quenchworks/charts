{{/* Every port the server listens on, as {name, port, servicePort, protocol}: container, Service and NetworkPolicy.
     With TLS the same port speaks HTTPS. */}}
{{- define "etherpad.ports" -}}
{{- toJson (list (dict "name" (ternary "https" "http" (eq (include "quench-common.tls.enabled" .) "true")) "port" 9001 "servicePort" (int .Values.service.port) "protocol" "TCP")) -}}
{{- end -}}

{{- define "etherpad.secretName" -}}
{{- .Values.secret.existingSecret | default (include "quench-common.fullname" .) -}}
{{- end -}}

{{/* Etherpad settings: the image's settings.json reads them from the environment. The database is the bundled
     PostgreSQL (its password under postgres-password) or externalDatabase. */}}
{{- define "etherpad.env" -}}
- { name: TITLE, value: {{ .Values.title | quote }} }
- { name: AUTHENTICATION_METHOD, value: {{ .Values.authenticationMethod | quote }} }
- { name: TRUST_PROXY, value: {{ .Values.trustProxy | quote }} }
- name: ADMIN_PASSWORD
  valueFrom:
    secretKeyRef: { name: {{ include "etherpad.secretName" . }}, key: admin-password }
- name: ADMIN_SECRET
  valueFrom:
    secretKeyRef: { name: {{ include "etherpad.secretName" . }}, key: sso-admin-secret }
- name: USER_SECRET
  valueFrom:
    secretKeyRef: { name: {{ include "etherpad.secretName" . }}, key: sso-user-secret }
{{- with .Values.publicURL }}
- { name: PUBLIC_URL, value: {{ . | quote }} }
- { name: SSO_ISSUER, value: {{ . | quote }} }
- { name: ADMIN_REDIRECT, value: {{ printf "%s/admin/" (trimSuffix "/" .) | quote }} }
- { name: USER_REDIRECT, value: {{ printf "%s/" (trimSuffix "/" .) | quote }} }
{{- end }}
- { name: DB_TYPE, value: postgres }
{{- if .Values.postgresql.enabled }}
- { name: DB_HOST, value: {{ printf "%s-postgresql" .Release.Name | quote }} }
- { name: DB_PORT, value: "5432" }
- { name: DB_NAME, value: {{ .Values.postgresql.auth.database | quote }} }
- { name: DB_USER, value: {{ .Values.postgresql.auth.username | quote }} }
- name: DB_PASS
  valueFrom:
    secretKeyRef: { name: {{ printf "%s-postgresql" .Release.Name }}, key: postgres-password }
{{- else }}
- { name: DB_HOST, value: {{ required "externalDatabase.host is required when postgresql.enabled=false" .Values.externalDatabase.host | quote }} }
- { name: DB_PORT, value: {{ .Values.externalDatabase.port | quote }} }
- { name: DB_NAME, value: {{ .Values.externalDatabase.database | quote }} }
- { name: DB_USER, value: {{ .Values.externalDatabase.username | quote }} }
- name: DB_PASS
  valueFrom:
    secretKeyRef: { name: {{ required "externalDatabase.existingSecret is required when postgresql.enabled=false" .Values.externalDatabase.existingSecret }}, key: {{ .Values.externalDatabase.existingSecretPasswordKey }} }
{{- end }}
{{- range $k, $v := .Values.settings }}
- { name: {{ $k }}, value: {{ $v | quote }} }
{{- end }}
{{- end -}}
