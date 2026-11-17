{{/* Every port the server listens on, as {name, port, servicePort, protocol}: container, Service and NetworkPolicy. */}}
{{- define "ghostfolio.ports" -}}
{{- toJson (list (dict "name" "http" "port" 3333 "servicePort" (int .Values.service.port) "protocol" "TCP")) -}}
{{- end -}}

{{- define "ghostfolio.secretName" -}}
{{- .Values.secret.existingSecret | default (include "quench-common.fullname" .) -}}
{{- end -}}

{{/* Ghostfolio settings. PostgreSQL and Valkey passwords come from the subcharts' own Secrets; DATABASE_URL splices
     the PostgreSQL one in by Kubernetes $(VAR) expansion (generated passwords are alphanumeric, URL-safe). */}}
{{- define "ghostfolio.env" -}}
- name: ACCESS_TOKEN_SALT
  valueFrom:
    secretKeyRef: { name: {{ include "ghostfolio.secretName" . }}, key: access-token-salt }
- name: JWT_SECRET_KEY
  valueFrom:
    secretKeyRef: { name: {{ include "ghostfolio.secretName" . }}, key: jwt-secret-key }
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
{{- if .Values.valkey.enabled }}
- { name: REDIS_HOST, value: {{ printf "%s-valkey" .Release.Name | quote }} }
- { name: REDIS_PORT, value: "6379" }
- name: REDIS_PASSWORD
  valueFrom:
    secretKeyRef: { name: {{ printf "%s-valkey" .Release.Name }}, key: valkey-password }
{{- else }}
- { name: REDIS_HOST, value: {{ required "externalRedis.host" .Values.externalRedis.host | quote }} }
- { name: REDIS_PORT, value: {{ .Values.externalRedis.port | quote }} }
{{- with .Values.externalRedis.existingSecret }}
- name: REDIS_PASSWORD
  valueFrom:
    secretKeyRef: { name: {{ . }}, key: {{ $.Values.externalRedis.existingSecretKey }} }
{{- end }}
{{- end }}
{{- range $k, $v := .Values.settings }}
- { name: {{ $k }}, value: {{ $v | quote }} }
{{- end }}
{{- end -}}
