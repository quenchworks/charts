{{/* =====================================================================
     Per-component naming + labels. Airflow 3 runs several roles (api-server,
     scheduler, dag-processor, triggerer, worker) as separate workloads from the same
     image; each gets its own objects distinguished by app.kubernetes.io/component.
     Mirrors the quench/authentik + quench/thanos layout.
   ===================================================================== */}}

{{/* Per-component fullname: "<release>-airflow-<component>". */}}
{{- define "airflow.componentFullname" -}}
{{- printf "%s-%s" (include "quench-common.fullname" .ctx) .component -}}
{{- end -}}

{{- define "airflow.componentLabels" -}}
{{ include "quench-common.labels" .ctx }}
app.kubernetes.io/component: {{ .component }}
{{- end -}}

{{- define "airflow.componentSelectorLabels" -}}
{{ include "quench-common.selectorLabels" .ctx }}
app.kubernetes.io/component: {{ .component }}
{{- end -}}

{{/* ServiceAccount name (one SA shared by all workloads). */}}
{{- define "airflow.serviceAccountName" -}}
{{- if .Values.serviceAccount.create -}}{{ default (include "quench-common.fullname" .) .Values.serviceAccount.name }}{{- else -}}{{ default "default" .Values.serviceAccount.name }}{{- end -}}
{{- end -}}

{{/* Name of the shared config ConfigMap (non-secret AIRFLOW__* env). */}}
{{- define "airflow.configMapName" -}}
{{- printf "%s-config" (include "quench-common.fullname" .) -}}
{{- end -}}

{{/* True when the CeleryExecutor is selected (needs a broker + worker workload). */}}
{{- define "airflow.isCelery" -}}
{{- if eq .Values.executor "CeleryExecutor" -}}true{{- end -}}
{{- end -}}

{{/* =====================================================================
     Chart-managed Secret: fernet-key + jwt-secret (unless an existingSecret is
     supplied), plus optional external-inline backend passwords.
   ===================================================================== */}}
{{- define "airflow.secretName" -}}
{{- if .Values.secrets.existingSecret -}}{{ .Values.secrets.existingSecret }}{{- else -}}{{ include "quench-common.fullname" . }}{{- end -}}
{{- end -}}

{{- define "airflow.fernetKeyName" -}}
{{- if .Values.secrets.existingSecret -}}{{ .Values.secrets.existingSecretFernetKey }}{{- else -}}fernet-key{{- end -}}
{{- end -}}

{{- define "airflow.jwtSecretKeyName" -}}
{{- if .Values.secrets.existingSecret -}}{{ .Values.secrets.existingSecretJwtKey }}{{- else -}}jwt-secret{{- end -}}
{{- end -}}

{{/* =====================================================================
     METADATA DATABASE resolution: bundled-PG -> external-PG. REQUIRED; the helpers
     fail with a clear message if neither mode resolves.
   ===================================================================== */}}
{{- define "airflow.postgres.host" -}}
{{- if .Values.postgresql.enabled -}}
{{- printf "%s-postgresql" .Release.Name -}}
{{- else -}}
{{- required "A PostgreSQL metadata database is REQUIRED: set postgresql.enabled=true (bundled) OR externalDatabase.host (external)." .Values.externalDatabase.host -}}
{{- end -}}
{{- end -}}

{{- define "airflow.postgres.port" -}}
{{- if .Values.postgresql.enabled -}}5432{{- else -}}{{ .Values.externalDatabase.port }}{{- end -}}
{{- end -}}

{{- define "airflow.postgres.database" -}}
{{- if .Values.postgresql.enabled -}}{{ .Values.postgresql.auth.database }}{{- else -}}{{ .Values.externalDatabase.database }}{{- end -}}
{{- end -}}

{{- define "airflow.postgres.username" -}}
{{- if .Values.postgresql.enabled -}}{{ .Values.postgresql.auth.username }}{{- else -}}{{ .Values.externalDatabase.username }}{{- end -}}
{{- end -}}

{{/* Secret + key the PostgreSQL password is sourced from.
     Bundled  => the postgresql subchart's OWN Secret "<release>-postgresql" (key
                 postgres-password).
     External w/ existingSecret => that Secret + its key.
     External w/o existingSecret => the chart's managed Secret (key db-password). */}}
{{- define "airflow.postgres.secretName" -}}
{{- if .Values.postgresql.enabled -}}
{{- printf "%s-postgresql" .Release.Name -}}
{{- else if .Values.externalDatabase.existingSecret -}}
{{- .Values.externalDatabase.existingSecret -}}
{{- else -}}
{{- include "quench-common.fullname" . -}}
{{- end -}}
{{- end -}}

{{- define "airflow.postgres.secretKey" -}}
{{- if .Values.postgresql.enabled -}}
postgres-password
{{- else if .Values.externalDatabase.existingSecret -}}
{{- .Values.externalDatabase.existingSecretPasswordKey -}}
{{- else -}}
db-password
{{- end -}}
{{- end -}}

{{/* =====================================================================
     CELERY BROKER resolution (only meaningful when executor: CeleryExecutor):
     bundled valkey -> bundled redis -> external. REQUIRED for Celery.
   ===================================================================== */}}
{{- define "airflow.redis.host" -}}
{{- if .Values.valkey.enabled -}}
{{- printf "%s-valkey" .Release.Name -}}
{{- else if .Values.redis.enabled -}}
{{- printf "%s-redis" .Release.Name -}}
{{- else -}}
{{- required "CeleryExecutor requires a broker: set valkey.enabled=true (recommended) OR redis.enabled=true (bundled) OR externalRedis.host (external)." .Values.externalRedis.host -}}
{{- end -}}
{{- end -}}

{{- define "airflow.redis.port" -}}
{{- if or .Values.valkey.enabled .Values.redis.enabled -}}6379{{- else -}}{{ .Values.externalRedis.port }}{{- end -}}
{{- end -}}

{{- define "airflow.redis.db" -}}
{{- if or .Values.valkey.enabled .Values.redis.enabled -}}0{{- else -}}{{ .Values.externalRedis.db }}{{- end -}}
{{- end -}}

{{- define "airflow.redis.hasPassword" -}}
{{- if or .Values.valkey.enabled .Values.redis.enabled -}}true
{{- else if or .Values.externalRedis.password .Values.externalRedis.existingSecret -}}true{{- end -}}
{{- end -}}

{{- define "airflow.redis.secretName" -}}
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

{{- define "airflow.redis.secretKey" -}}
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
     Shared pod env for EVERY workload (and the migrate Job): the Fernet key, the JWT
     secret, and the metadata-DB wiring. The SQLAlchemy connection string is assembled
     from discrete env vars using Kubernetes $(VAR) interpolation so the password never
     leaves its Secret in plaintext. For CeleryExecutor the broker URL + result backend
     are appended the same way. Call with the root context.
   ===================================================================== */}}
{{- define "airflow.backendEnv" -}}
- name: AIRFLOW__CORE__FERNET_KEY
  valueFrom:
    secretKeyRef:
      name: {{ include "airflow.secretName" . }}
      key: {{ include "airflow.fernetKeyName" . }}
- name: AIRFLOW__API_AUTH__JWT_SECRET
  valueFrom:
    secretKeyRef:
      name: {{ include "airflow.secretName" . }}
      key: {{ include "airflow.jwtSecretKeyName" . }}
- name: DB_HOST
  value: {{ include "airflow.postgres.host" . | quote }}
- name: DB_PORT
  value: {{ include "airflow.postgres.port" . | quote }}
- name: DB_NAME
  value: {{ include "airflow.postgres.database" . | quote }}
- name: DB_USER
  value: {{ include "airflow.postgres.username" . | quote }}
- name: DB_PASSWORD
  valueFrom:
    secretKeyRef:
      name: {{ include "airflow.postgres.secretName" . }}
      key: {{ include "airflow.postgres.secretKey" . }}
- name: AIRFLOW__DATABASE__SQL_ALCHEMY_CONN
  value: "postgresql+psycopg2://$(DB_USER):$(DB_PASSWORD)@$(DB_HOST):$(DB_PORT)/$(DB_NAME)"
{{- if include "airflow.isCelery" . }}
- name: REDIS_HOST
  value: {{ include "airflow.redis.host" . | quote }}
- name: REDIS_PORT
  value: {{ include "airflow.redis.port" . | quote }}
- name: REDIS_DB
  value: {{ include "airflow.redis.db" . | quote }}
{{- if include "airflow.redis.hasPassword" . }}
- name: REDIS_PASSWORD
  valueFrom:
    secretKeyRef:
      name: {{ include "airflow.redis.secretName" . }}
      key: {{ include "airflow.redis.secretKey" . }}
- name: AIRFLOW__CELERY__BROKER_URL
  value: "redis://:$(REDIS_PASSWORD)@$(REDIS_HOST):$(REDIS_PORT)/$(REDIS_DB)"
{{- else }}
- name: AIRFLOW__CELERY__BROKER_URL
  value: "redis://$(REDIS_HOST):$(REDIS_PORT)/$(REDIS_DB)"
{{- end }}
- name: AIRFLOW__CELERY__RESULT_BACKEND
  value: "db+postgresql://$(DB_USER):$(DB_PASSWORD)@$(DB_HOST):$(DB_PORT)/$(DB_NAME)"
{{- end }}
{{- end -}}

{{/* =====================================================================
     Init container that blocks a component until the metadata DB schema is migrated.
     `airflow db check-migrations -t <timeout>` exits 0 once migrations are applied; if
     the DB is briefly unreachable the init container fails and the pod retries the init
     sequence. This is how every component "waits for" the migrate Job. Shell-free (the
     runtime image ships no shell): exec the airflow binary directly.
   ===================================================================== */}}
{{- define "airflow.waitForMigrations" -}}
- name: wait-for-migrations
  image: {{ include "quench-common.image" . }}
  imagePullPolicy: {{ .Values.image.pullPolicy }}
  securityContext:
    {{- include "quench-common.containerSecurityContext" . | nindent 4 }}
  args:
    - db
    - check-migrations
    - --migration-wait-timeout
    - {{ .Values.migrateDatabase.waitTimeout | quote }}
  env:
    {{- include "airflow.backendEnv" . | nindent 4 }}
  envFrom:
    - configMapRef:
        name: {{ include "airflow.configMapName" . }}
  volumeMounts:
    - name: airflow-home
      mountPath: /opt/airflow
    - name: tmp
      mountPath: /tmp
  resources:
    {{- toYaml .Values.migrateDatabase.resources | nindent 4 }}
{{- end -}}

{{/* =====================================================================
     The two writable paths on the read-only rootfs, shared by every workload:
     AIRFLOW_HOME (/opt/airflow: airflow.cfg, logs, generated password file) and /tmp.
     Emitted as an emptyDir volume pair + the matching mounts.
   ===================================================================== */}}
{{- define "airflow.writableVolumes" -}}
- name: airflow-home
  emptyDir: {}
- name: tmp
  emptyDir: {}
{{- end -}}

{{- define "airflow.writableVolumeMounts" -}}
- name: airflow-home
  mountPath: /opt/airflow
- name: tmp
  mountPath: /tmp
{{- end -}}
