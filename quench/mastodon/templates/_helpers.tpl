{{- define "mastodon.serviceAccountName" -}}
{{- if .Values.serviceAccount.create -}}{{ default (include "quench-common.fullname" .) .Values.serviceAccount.name }}{{- else -}}{{ default "default" .Values.serviceAccount.name }}{{- end -}}
{{- end -}}

{{/* Selector labels for one component (web, sidekiq, streaming). */}}
{{- define "mastodon.selectorLabels" -}}
{{ include "quench-common.selectorLabels" .ctx }}
app.kubernetes.io/component: {{ .component }}
{{- end -}}

{{/* Database: the bundled postgresql subchart, or externalDatabase. */}}
{{- define "mastodon.db.host" -}}
{{- if .Values.postgresql.enabled -}}{{ printf "%s-postgresql" .Release.Name }}{{- else -}}{{ required "externalDatabase.host is required when postgresql.enabled=false" .Values.externalDatabase.host }}{{- end -}}
{{- end -}}
{{- define "mastodon.db.port" -}}
{{- if .Values.postgresql.enabled -}}5432{{- else -}}{{ .Values.externalDatabase.port }}{{- end -}}
{{- end -}}
{{- define "mastodon.db.name" -}}
{{- if .Values.postgresql.enabled -}}{{ .Values.postgresql.auth.database }}{{- else -}}{{ .Values.externalDatabase.database }}{{- end -}}
{{- end -}}
{{- define "mastodon.db.user" -}}
{{- if .Values.postgresql.enabled -}}{{ .Values.postgresql.auth.username }}{{- else -}}{{ .Values.externalDatabase.username }}{{- end -}}
{{- end -}}
{{/* The bundled PostgreSQL creates auth.username as its superuser, with the password
     under postgres-password in its own Secret. */}}
{{- define "mastodon.db.secretName" -}}
{{- if .Values.postgresql.enabled -}}{{ printf "%s-postgresql" .Release.Name }}
{{- else if .Values.externalDatabase.existingSecret -}}{{ .Values.externalDatabase.existingSecret }}
{{- else -}}{{ include "quench-common.fullname" . }}{{- end -}}
{{- end -}}
{{- define "mastodon.db.secretKey" -}}
{{- if .Values.postgresql.enabled -}}postgres-password
{{- else if .Values.externalDatabase.existingSecret -}}{{ .Values.externalDatabase.existingSecretPasswordKey }}
{{- else -}}db-password{{- end -}}
{{- end -}}

{{/* Redis: the bundled valkey subchart (its own Secret, key valkey-password), or externalRedis. */}}
{{- define "mastodon.redis.host" -}}
{{- if .Values.valkey.enabled -}}{{ printf "%s-valkey" .Release.Name }}{{- else -}}{{ required "externalRedis.host is required when valkey.enabled=false" .Values.externalRedis.host }}{{- end -}}
{{- end -}}
{{- define "mastodon.redis.port" -}}
{{- if .Values.valkey.enabled -}}6379{{- else -}}{{ .Values.externalRedis.port }}{{- end -}}
{{- end -}}
{{- define "mastodon.redis.password" -}}
{{- if .Values.valkey.enabled }}
- name: REDIS_PASSWORD
  valueFrom:
    secretKeyRef:
      name: {{ printf "%s-valkey" .Release.Name }}
      key: valkey-password
{{- else if .Values.externalRedis.existingSecret }}
- name: REDIS_PASSWORD
  valueFrom:
    secretKeyRef:
      name: {{ .Values.externalRedis.existingSecret }}
      key: {{ .Values.externalRedis.existingSecretPasswordKey }}
{{- else if .Values.externalRedis.password }}
- name: REDIS_PASSWORD
  valueFrom:
    secretKeyRef:
      name: {{ include "quench-common.fullname" . }}
      key: redis-password
{{- end }}
{{- end -}}

{{- define "mastodon.secretName" -}}
{{- default (include "quench-common.fullname" .) .Values.secrets.existingSecret -}}
{{- end -}}

{{/* Connection environment shared by every container. */}}
{{- define "mastodon.connEnv" -}}
- { name: DB_HOST, value: {{ include "mastodon.db.host" . | quote }} }
- { name: DB_PORT, value: {{ include "mastodon.db.port" . | quote }} }
- { name: DB_NAME, value: {{ include "mastodon.db.name" . | quote }} }
- { name: DB_USER, value: {{ include "mastodon.db.user" . | quote }} }
- name: DB_PASS
  valueFrom:
    secretKeyRef:
      name: {{ include "mastodon.db.secretName" . }}
      key: {{ include "mastodon.db.secretKey" . }}
- { name: REDIS_HOST, value: {{ include "mastodon.redis.host" . | quote }} }
- { name: REDIS_PORT, value: {{ include "mastodon.redis.port" . | quote }} }
{{- include "mastodon.redis.password" . }}
{{- end -}}

{{/* Rails environment for web, sidekiq and the schema step. */}}
{{- define "mastodon.railsEnv" -}}
{{ include "mastodon.connEnv" . }}
- { name: LOCAL_DOMAIN, value: {{ required "localDomain is required" .Values.localDomain | quote }} }
{{- with .Values.webDomain }}
- { name: WEB_DOMAIN, value: {{ . | quote }} }
{{- end }}
- { name: REGISTRATIONS_MODE, value: {{ .Values.registrationsMode | quote }} }
{{- $s := include "mastodon.secretName" . }}
{{- range $env, $key := dict "SECRET_KEY_BASE" "secret-key-base" "OTP_SECRET" "otp-secret" "ACTIVE_RECORD_ENCRYPTION_DETERMINISTIC_KEY" "ar-deterministic-key" "ACTIVE_RECORD_ENCRYPTION_KEY_DERIVATION_SALT" "ar-key-derivation-salt" "ACTIVE_RECORD_ENCRYPTION_PRIMARY_KEY" "ar-primary-key" }}
- name: {{ $env }}
  valueFrom:
    secretKeyRef:
      name: {{ $s }}
      key: {{ $key }}
{{- end }}
{{- with .Values.extraEnvVars }}
{{ toYaml . }}
{{- end }}
{{- end -}}
