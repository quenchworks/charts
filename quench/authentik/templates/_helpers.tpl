{{/* =====================================================================
     Per-component naming + labels (server / worker). Two workloads run from the
     same image; each gets its own objects distinguished by the
     app.kubernetes.io/component dimension. Mirrors the quench/thanos layout.
   ===================================================================== */}}

{{/* Per-component fullname: "<release>-authentik-<component>". */}}
{{- define "authentik.componentFullname" -}}
{{- printf "%s-%s" (include "quench-common.fullname" .ctx) .component -}}
{{- end -}}

{{/* Common labels for a component. */}}
{{- define "authentik.componentLabels" -}}
{{ include "quench-common.labels" .ctx }}
app.kubernetes.io/component: {{ .component }}
{{- end -}}

{{/* Selector labels for a component (stable subset of componentLabels). */}}
{{- define "authentik.componentSelectorLabels" -}}
{{ include "quench-common.selectorLabels" .ctx }}
app.kubernetes.io/component: {{ .component }}
{{- end -}}

{{/* ServiceAccount name (one SA shared by both workloads). */}}
{{- define "authentik.serviceAccountName" -}}
{{- if .Values.serviceAccount.create -}}{{ default (include "quench-common.fullname" .) .Values.serviceAccount.name }}{{- else -}}{{ default "default" .Values.serviceAccount.name }}{{- end -}}
{{- end -}}

{{/* Name of the shared config ConfigMap (non-secret AUTHENTIK_* env). */}}
{{- define "authentik.configMapName" -}}
{{- printf "%s-config" (include "quench-common.fullname" .) -}}
{{- end -}}

{{/* Name of the chart-managed Secret. An externally-managed Secret
     (secrets.existingSecret) wins over the chart-rendered one for the secret key. */}}
{{- define "authentik.secretName" -}}
{{- if .Values.secrets.existingSecret -}}{{ .Values.secrets.existingSecret }}{{- else -}}{{ include "quench-common.fullname" . }}{{- end -}}
{{- end -}}

{{- define "authentik.secretKeyName" -}}
{{- if .Values.secrets.existingSecret -}}{{ .Values.secrets.existingSecretKey }}{{- else -}}authentik-secret-key{{- end -}}
{{- end -}}

{{/* =====================================================================
     DATABASE resolution: bundled-PG -> external-PG. PostgreSQL is REQUIRED; the
     helpers fail with a clear message if neither mode resolves.
   ===================================================================== */}}
{{- define "authentik.postgres.host" -}}
{{- if .Values.postgresql.enabled -}}
{{- printf "%s-postgresql" .Release.Name -}}
{{- else -}}
{{- required "A PostgreSQL is REQUIRED: set postgresql.enabled=true (bundled) OR externalDatabase.host (external)." .Values.externalDatabase.host -}}
{{- end -}}
{{- end -}}

{{- define "authentik.postgres.port" -}}
{{- if .Values.postgresql.enabled -}}5432{{- else -}}{{ .Values.externalDatabase.port }}{{- end -}}
{{- end -}}

{{- define "authentik.postgres.database" -}}
{{- if .Values.postgresql.enabled -}}{{ .Values.postgresql.auth.database }}{{- else -}}{{ .Values.externalDatabase.database }}{{- end -}}
{{- end -}}

{{- define "authentik.postgres.username" -}}
{{- if .Values.postgresql.enabled -}}{{ .Values.postgresql.auth.username }}{{- else -}}{{ .Values.externalDatabase.username }}{{- end -}}
{{- end -}}

{{/* Secret + key the PostgreSQL password is sourced from.
     Bundled  => the postgresql subchart's OWN Secret "<release>-postgresql"
                 (key postgres-password); reading it directly avoids duplication.
     External w/ existingSecret => that Secret + its key.
     External w/o existingSecret => the chart's managed Secret. */}}
{{- define "authentik.postgres.secretName" -}}
{{- if .Values.postgresql.enabled -}}
{{- printf "%s-postgresql" .Release.Name -}}
{{- else if .Values.externalDatabase.existingSecret -}}
{{- .Values.externalDatabase.existingSecret -}}
{{- else -}}
{{- include "quench-common.fullname" . -}}
{{- end -}}
{{- end -}}

{{- define "authentik.postgres.secretKey" -}}
{{- if .Values.postgresql.enabled -}}
postgres-password
{{- else if .Values.externalDatabase.existingSecret -}}
{{- .Values.externalDatabase.existingSecretPasswordKey -}}
{{- else -}}
db-password
{{- end -}}
{{- end -}}

{{/* =====================================================================
     REDIS resolution (precedence): bundled valkey -> bundled redis -> external.
     Redis is REQUIRED; enable AT MOST ONE bundled store (valkey wins if both set).
   ===================================================================== */}}
{{- define "authentik.redis.host" -}}
{{- if .Values.valkey.enabled -}}
{{- printf "%s-valkey" .Release.Name -}}
{{- else if .Values.redis.enabled -}}
{{- printf "%s-redis" .Release.Name -}}
{{- else -}}
{{- required "A Redis is REQUIRED: set valkey.enabled=true (recommended) OR redis.enabled=true (bundled) OR externalRedis.host (external)." .Values.externalRedis.host -}}
{{- end -}}
{{- end -}}

{{- define "authentik.redis.port" -}}
{{- if or .Values.valkey.enabled .Values.redis.enabled -}}6379{{- else -}}{{ .Values.externalRedis.port }}{{- end -}}
{{- end -}}

{{- define "authentik.redis.db" -}}
{{- if or .Values.valkey.enabled .Values.redis.enabled -}}0{{- else -}}{{ .Values.externalRedis.db }}{{- end -}}
{{- end -}}

{{/* Whether the Redis store needs a password. Both bundled stores ship auth ON, so
     they always need one. External is password-protected only when a password or
     existingSecret is supplied. */}}
{{- define "authentik.redis.hasPassword" -}}
{{- if or .Values.valkey.enabled .Values.redis.enabled -}}true
{{- else if or .Values.externalRedis.password .Values.externalRedis.existingSecret -}}true{{- end -}}
{{- end -}}

{{/* Secret + key the Redis password is sourced from. */}}
{{- define "authentik.redis.secretName" -}}
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

{{- define "authentik.redis.secretKey" -}}
{{- if .Values.valkey.enabled -}}
valkey-password
{{- else if .Values.redis.enabled -}}
redis-password
{{- else if .Values.externalRedis.existingSecret -}}
{{- .Values.externalRedis.existingSecretPasswordKey -}}
{{- else -}}
redis-password
{{- end -}}
{{- end -}}

{{/* =====================================================================
     Shared pod env for BOTH workloads: the secret key, the PostgreSQL wiring, and
     the Redis wiring. Authentik reads all of these as AUTHENTIK_* env vars. Passwords
     are pulled from the resolved Secret(s) via secretKeyRef (no plaintext duplication).
     Call with the root context: {{ include "authentik.backendEnv" . }}
   ===================================================================== */}}
{{- define "authentik.backendEnv" -}}
- name: AUTHENTIK_SECRET_KEY
  valueFrom:
    secretKeyRef:
      name: {{ include "authentik.secretName" . }}
      key: {{ include "authentik.secretKeyName" . }}
- name: AUTHENTIK_POSTGRESQL__HOST
  value: {{ include "authentik.postgres.host" . | quote }}
- name: AUTHENTIK_POSTGRESQL__PORT
  value: {{ include "authentik.postgres.port" . | quote }}
- name: AUTHENTIK_POSTGRESQL__NAME
  value: {{ include "authentik.postgres.database" . | quote }}
- name: AUTHENTIK_POSTGRESQL__USER
  value: {{ include "authentik.postgres.username" . | quote }}
- name: AUTHENTIK_POSTGRESQL__PASSWORD
  valueFrom:
    secretKeyRef:
      name: {{ include "authentik.postgres.secretName" . }}
      key: {{ include "authentik.postgres.secretKey" . }}
- name: AUTHENTIK_REDIS__HOST
  value: {{ include "authentik.redis.host" . | quote }}
- name: AUTHENTIK_REDIS__PORT
  value: {{ include "authentik.redis.port" . | quote }}
- name: AUTHENTIK_REDIS__DB
  value: {{ include "authentik.redis.db" . | quote }}
{{- if include "authentik.redis.hasPassword" . }}
- name: AUTHENTIK_REDIS__PASSWORD
  valueFrom:
    secretKeyRef:
      name: {{ include "authentik.redis.secretName" . }}
      key: {{ include "authentik.redis.secretKey" . }}
{{- end }}
{{- end -}}
