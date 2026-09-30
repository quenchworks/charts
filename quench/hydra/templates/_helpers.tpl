{{- define "hydra.serviceAccountName" -}}
{{- if .Values.serviceAccount.create -}}{{ default (include "quench-common.fullname" .) .Values.serviceAccount.name }}{{- else -}}{{ default "default" .Values.serviceAccount.name }}{{- end -}}
{{- end -}}

{{/*
Database wiring. When postgresql.enabled the bundled subchart's primary Service is
named "<release>-postgresql" (the subchart's quench-common.fullname resolves against
its own chart name "postgresql"); credentials come from this chart's postgresql.auth.
When external, everything comes from externalDatabase.
*/}}
{{- define "hydra.db.host" -}}
{{- if .Values.postgresql.enabled -}}
{{- printf "%s-postgresql" .Release.Name -}}
{{- else -}}
{{- required "externalDatabase.host is required when postgresql.enabled=false" .Values.externalDatabase.host -}}
{{- end -}}
{{- end -}}

{{- define "hydra.db.port" -}}
{{- if .Values.postgresql.enabled -}}5432{{- else -}}{{ .Values.externalDatabase.port }}{{- end -}}
{{- end -}}

{{- define "hydra.db.name" -}}
{{- if .Values.postgresql.enabled -}}{{ .Values.postgresql.auth.database }}{{- else -}}{{ .Values.externalDatabase.database }}{{- end -}}
{{- end -}}

{{- define "hydra.db.user" -}}
{{- if .Values.postgresql.enabled -}}{{ .Values.postgresql.auth.username }}{{- else -}}{{ .Values.externalDatabase.user }}{{- end -}}
{{- end -}}

{{- define "hydra.db.sslMode" -}}
{{- if .Values.postgresql.enabled -}}disable{{- else -}}{{ .Values.externalDatabase.sslMode }}{{- end -}}
{{- end -}}

{{/* Name of the Secret holding the DSN + system secret, and the DSN key within it. */}}
{{- define "hydra.secretName" -}}
{{- if and (not .Values.postgresql.enabled) .Values.externalDatabase.existingSecret -}}
{{- .Values.externalDatabase.existingSecret -}}
{{- else -}}
{{- include "quench-common.fullname" . -}}
{{- end -}}
{{- end -}}

{{- define "hydra.db.secretDsnKey" -}}
{{- if and (not .Values.postgresql.enabled) .Values.externalDatabase.existingSecret -}}
{{- .Values.externalDatabase.existingSecretDsnKey -}}
{{- else -}}
dsn
{{- end -}}
{{- end -}}

{{- define "hydra.secretsSystemKey" -}}
{{- if and (not .Values.postgresql.enabled) .Values.externalDatabase.existingSecret -}}
{{- .Values.externalDatabase.existingSecretSecretsSystemKey -}}
{{- else -}}
secrets-system
{{- end -}}
{{- end -}}

{{/* Whether this chart renders its own managed Secret. */}}
{{- define "hydra.manageSecret" -}}
{{- if or .Values.postgresql.enabled (not .Values.externalDatabase.existingSecret) -}}true{{- end -}}
{{- end -}}

{{/* True when the pod must read the DB password from the bundled PostgreSQL chart's Secret:
     the subchart generated it (or reads an existingSecret), so this chart cannot know it
     at render time. lookup finds nothing on a first install, and a copy generated here
     would never match. */}}
{{- define "hydra.db.fromSubchart" -}}
{{- if and .Values.postgresql.enabled (not .Values.postgresql.auth.password) -}}true{{- end -}}
{{- end -}}

{{/* The DSN env entry. With the password from the subchart, the kubelet expands
     $(DB_PASSWORD) into the DSN; the subchart generates an alphanumeric password, and an
     explicit postgresql.auth.password takes the Secret path below instead. */}}
{{- define "hydra.dsnEnv" -}}
{{- if include "hydra.db.fromSubchart" . }}
- name: DB_PASSWORD
  valueFrom:
    secretKeyRef:
      name: {{ .Values.postgresql.auth.existingSecret | default (printf "%s-postgresql" .Release.Name) }}
      key: {{ ternary (.Values.postgresql.auth.existingSecretPasswordKey | default "postgres-password") "postgres-password" (not (empty .Values.postgresql.auth.existingSecret)) }}
- name: DSN
  value: {{ printf "postgres://%s:$(DB_PASSWORD)@%s:%s/%s?sslmode=%s&max_conn_lifetime=10m" (include "hydra.db.user" .) (include "hydra.db.host" .) (include "hydra.db.port" .) (include "hydra.db.name" .) (include "hydra.db.sslMode" .) | quote }}
{{- else }}
- name: DSN
  valueFrom:
    secretKeyRef:
      name: {{ include "hydra.secretName" . }}
      key: {{ include "hydra.db.secretDsnKey" . }}
{{- end }}
{{- end -}}
