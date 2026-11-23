{{/* The web port: Quarkus on 8082 (HTTPS on the same port with TLS). */}}
{{- define "commafeed.ports" -}}
{{- toJson (list (dict "name" (ternary "https" "http" (eq (include "quench-common.tls.enabled" .) "true")) "port" 8082 "servicePort" (int .Values.service.port) "protocol" "TCP")) -}}
{{- end -}}

{{- define "commafeed.secretName" -}}
{{- .Values.secret.existingSecret | default (include "quench-common.fullname" .) -}}
{{- end -}}

{{/* Quarkus reads its configuration from the environment (QUARKUS_*, COMMAFEED_*). */}}
{{- define "commafeed.env" -}}
{{- $tls := eq (include "quench-common.tls.enabled" .) "true" -}}
{{- if .Values.postgresql.enabled }}
- { name: QUARKUS_DATASOURCE_JDBC_URL, value: {{ printf "jdbc:postgresql://%s-postgresql:5432/%s" .Release.Name .Values.postgresql.auth.database | quote }} }
- { name: QUARKUS_DATASOURCE_USERNAME, value: {{ .Values.postgresql.auth.username | quote }} }
- name: QUARKUS_DATASOURCE_PASSWORD
  valueFrom:
    secretKeyRef: { name: {{ printf "%s-postgresql" .Release.Name }}, key: postgres-password }
{{- else }}
- { name: QUARKUS_DATASOURCE_JDBC_URL, value: {{ printf "jdbc:postgresql://%s:%d/%s" (required "externalDatabase.host is required when postgresql.enabled=false" .Values.externalDatabase.host) (int .Values.externalDatabase.port) .Values.externalDatabase.database | quote }} }
- { name: QUARKUS_DATASOURCE_USERNAME, value: {{ .Values.externalDatabase.username | quote }} }
- name: QUARKUS_DATASOURCE_PASSWORD
  valueFrom:
    secretKeyRef: { name: {{ required "externalDatabase.existingSecret is required when postgresql.enabled=false" .Values.externalDatabase.existingSecret }}, key: {{ .Values.externalDatabase.existingSecretPasswordKey }} }
{{- end }}
- name: QUARKUS_HTTP_AUTH_SESSION_ENCRYPTION_KEY
  valueFrom:
    secretKeyRef: { name: {{ include "commafeed.secretName" . }}, key: session-key }
- { name: COMMAFEED_USERS_ALLOW_REGISTRATIONS, value: {{ .Values.allowRegistrations | quote }} }
{{- with .Values.publicUrl }}
- { name: COMMAFEED_PASSWORD_RECOVERY_PUBLIC_BASE_URL, value: {{ . | quote }} }
{{- end }}
{{- if $tls }}
# Quarkus serves HTTPS itself from the PEM pair at /tls, on the same port
- { name: QUARKUS_HTTP_SSL_PORT, value: "8082" }
- { name: QUARKUS_HTTP_PORT, value: "8081" }
- { name: QUARKUS_HTTP_INSECURE_REQUESTS, value: disabled }
- { name: QUARKUS_HTTP_SSL_CERTIFICATE_FILES, value: /tls/tls.crt }
- { name: QUARKUS_HTTP_SSL_CERTIFICATE_KEY_FILES, value: /tls/tls.key }
{{- end }}
{{- with .Values.javaOpts }}
- { name: JAVA_TOOL_OPTIONS, value: {{ . | quote }} }
{{- end }}
{{- range $k, $v := .Values.settings }}
- { name: {{ $k }}, value: {{ $v | quote }} }
{{- end }}
{{- end -}}
