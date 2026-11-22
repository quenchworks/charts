{{/* Every port the server listens on, as {name, port, servicePort, protocol}: container, Service and NetworkPolicy.
     With TLS the same port speaks HTTPS. */}}
{{- define "pentagi.ports" -}}
{{- toJson (list (dict "name" (ternary "https" "http" (eq (include "quench-common.tls.enabled" .) "true")) "port" 8443 "servicePort" (int .Values.service.port) "protocol" "TCP")) -}}
{{- end -}}

{{- define "pentagi.secretName" -}}
{{- .Values.secret.existingSecret | default (include "quench-common.fullname" .) -}}
{{- end -}}

{{/* The database as DB_HOST, DB_PORT, DB_NAME, DB_USER and DB_PASS: the bundled PostgreSQL (its superuser, password
     under postgres-password) or externalDatabase. Shared by the server and the bootstrap Job. */}}
{{- define "pentagi.dbEnv" -}}
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
{{- end -}}

{{/* Server settings. DATABASE_URL is assembled from DB_* by the kubelet ($(VAR) expansion), so the password never
     sits in the pod spec; it must be URL-safe (the subchart generates alphanumerics). */}}
{{- define "pentagi.env" -}}
{{ include "pentagi.dbEnv" . }}
- { name: DATABASE_URL, value: "postgres://$(DB_USER):$(DB_PASS)@$(DB_HOST):$(DB_PORT)/$(DB_NAME)?sslmode={{ .Values.externalDatabase.sslmode }}" }
- name: COOKIE_SIGNING_SALT
  valueFrom:
    secretKeyRef: { name: {{ include "pentagi.secretName" . }}, key: cookie-signing-salt }
- { name: DOCKER_HOST, value: {{ ternary "tcp://127.0.0.1:2375" .Values.docker.host .Values.docker.sidecar.enabled | quote }} }
{{- with .Values.docker.network }}
- { name: DOCKER_NETWORK, value: {{ . | quote }} }
{{- end }}
{{- with .Values.publicURL }}
- { name: CORS_ORIGINS, value: {{ trimSuffix "/" . | quote }} }
{{- end }}
{{- if eq (include "quench-common.tls.enabled" .) "true" }}
- { name: SERVER_USE_SSL, value: "true" }
- { name: SERVER_SSL_CRT, value: /tls/tls.crt }
- { name: SERVER_SSL_KEY, value: /tls/tls.key }
{{- end }}
{{- range $k, $v := .Values.settings }}
- { name: {{ $k }}, value: {{ $v | quote }} }
{{- end }}
{{- end -}}
