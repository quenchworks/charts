{{- define "authelia.serviceAccountName" -}}
{{- if .Values.serviceAccount.create -}}{{ default (include "quench-common.fullname" .) .Values.serviceAccount.name }}{{- else -}}{{ default "default" .Values.serviceAccount.name }}{{- end -}}
{{- end -}}

{{/* Name of the ConfigMap holding configuration.yml. */}}
{{- define "authelia.configMapName" -}}
{{- printf "%s-config" (include "quench-common.fullname" .) -}}
{{- end -}}

{{/* Name of the Secret holding the three mandatory secrets. An externally-managed
     Secret (secrets.existingSecret) wins over the chart-rendered one. */}}
{{- define "authelia.secretName" -}}
{{- if .Values.secrets.existingSecret -}}{{ .Values.secrets.existingSecret }}{{- else -}}{{ include "quench-common.fullname" . }}{{- end -}}
{{- end -}}

{{/* =====================================================================
     STORAGE backend resolution: bundled-PG -> external-PG -> SQLite.
     postgresUsed is true when EITHER the bundled subchart is enabled OR an
     external host is configured. When true, the chart renders storage.postgres
     and drops storage.local.
   ===================================================================== */}}
{{- define "authelia.postgresUsed" -}}
{{- if or .Values.postgresql.enabled .Values.externalDatabase.host -}}true{{- end -}}
{{- end -}}

{{/* Bundled subchart's primary Service is "<release>-postgresql" (the postgresql
     dependency aliased "postgresql"; its quench-common.fullname resolves against
     its own chart name). External points at externalDatabase.host. */}}
{{- define "authelia.postgres.host" -}}
{{- if .Values.postgresql.enabled -}}
{{- printf "%s-postgresql" .Release.Name -}}
{{- else -}}
{{- required "externalDatabase.host is required when postgresql.enabled=false and you set externalDatabase.*" .Values.externalDatabase.host -}}
{{- end -}}
{{- end -}}

{{- define "authelia.postgres.port" -}}
{{- if .Values.postgresql.enabled -}}5432{{- else -}}{{ .Values.externalDatabase.port }}{{- end -}}
{{- end -}}

{{- define "authelia.postgres.database" -}}
{{- if .Values.postgresql.enabled -}}{{ .Values.postgresql.auth.database }}{{- else -}}{{ .Values.externalDatabase.database }}{{- end -}}
{{- end -}}

{{- define "authelia.postgres.username" -}}
{{- if .Values.postgresql.enabled -}}{{ .Values.postgresql.auth.username }}{{- else -}}{{ .Values.externalDatabase.username }}{{- end -}}
{{- end -}}

{{/* Secret + key that AUTHELIA_STORAGE_POSTGRES_PASSWORD_FILE is sourced from.
     Bundled => the postgresql subchart's OWN Secret "<release>-postgresql" (key
       postgres-password); reading it directly means no value duplication and the
       deterministic postgresql.auth.password is honored.
     External with existingSecret => that Secret + its key.
     External without existingSecret => the chart's managed Secret. */}}
{{- define "authelia.postgres.secretName" -}}
{{- if .Values.postgresql.enabled -}}
{{- printf "%s-postgresql" .Release.Name -}}
{{- else if .Values.externalDatabase.existingSecret -}}
{{- .Values.externalDatabase.existingSecret -}}
{{- else -}}
{{- include "quench-common.fullname" . -}}
{{- end -}}
{{- end -}}

{{- define "authelia.postgres.secretKey" -}}
{{- if .Values.postgresql.enabled -}}
postgres-password
{{- else if .Values.externalDatabase.existingSecret -}}
{{- .Values.externalDatabase.existingSecretPasswordKey -}}
{{- else -}}
storage-postgres-password
{{- end -}}
{{- end -}}

{{/* =====================================================================
     SESSION backend resolution (precedence): bundled valkey -> bundled redis ->
     external Redis/Valkey -> in-memory (default). The user enables AT MOST ONE of
     valkey.enabled / redis.enabled; if both are set, VALKEY wins.
   ===================================================================== */}}
{{- define "authelia.redisUsed" -}}
{{- if or .Values.valkey.enabled .Values.redis.enabled .Values.externalRedis.host -}}true{{- end -}}
{{- end -}}

{{/* Bundled subchart Services resolve to "<release>-<alias>" via quench-common.fullname
     against the subchart's own chart name (= the alias). So valkey => "<release>-valkey"
     and redis => "<release>-redis". External points at externalRedis.host. */}}
{{- define "authelia.redis.host" -}}
{{- if .Values.valkey.enabled -}}
{{- printf "%s-valkey" .Release.Name -}}
{{- else if .Values.redis.enabled -}}
{{- printf "%s-redis" .Release.Name -}}
{{- else -}}
{{- required "externalRedis.host is required when neither valkey.enabled nor redis.enabled is set and you configure externalRedis.*" .Values.externalRedis.host -}}
{{- end -}}
{{- end -}}

{{- define "authelia.redis.port" -}}
{{- if or .Values.valkey.enabled .Values.redis.enabled -}}6379{{- else -}}{{ .Values.externalRedis.port }}{{- end -}}
{{- end -}}

{{/* Whether the session store needs a password file. Both bundled stores ship with
     auth ON, so they always need one. External is password-protected only when a
     password or existingSecret is supplied. */}}
{{- define "authelia.redis.hasPassword" -}}
{{- if or .Values.valkey.enabled .Values.redis.enabled -}}true
{{- else if or .Values.externalRedis.password .Values.externalRedis.existingSecret -}}true{{- end -}}
{{- end -}}

{{/* Secret + key that AUTHELIA_SESSION_REDIS_PASSWORD_FILE is sourced from.
     Bundled valkey => valkey's OWN Secret "<release>-valkey" (key valkey-password).
     Bundled redis  => redis's OWN Secret  "<release>-redis"  (key redis-password).
       Reading the subchart Secret directly means no value duplication and an empty
       password (subchart-generated) still works.
     External with existingSecret => that Secret + its key.
     External without existingSecret => the chart's managed Secret. */}}
{{- define "authelia.redis.secretName" -}}
{{- if .Values.valkey.enabled -}}
{{- printf "%s-valkey" .Release.Name -}}
{{- else if .Values.redis.enabled -}}
{{- printf "%s-redis" .Release.Name -}}
{{- else if .Values.externalRedis.existingSecret -}}
{{- .Values.externalRedis.existingSecret -}}
{{- else -}}
{{- include "quench-common.fullname" . -}}
{{- end -}}
{{- end -}}

{{- define "authelia.redis.secretKey" -}}
{{- if .Values.valkey.enabled -}}
valkey-password
{{- else if .Values.redis.enabled -}}
redis-password
{{- else if .Values.externalRedis.existingSecret -}}
{{- .Values.externalRedis.existingSecretPasswordKey -}}
{{- else -}}
session-redis-password
{{- end -}}
{{- end -}}
