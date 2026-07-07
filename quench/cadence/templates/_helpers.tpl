{{- define "cadence.serviceAccountName" -}}
{{- if .Values.serviceAccount.create -}}{{ default (include "quench-common.fullname" .) .Values.serviceAccount.name }}{{- else -}}{{ default "default" .Values.serviceAccount.name }}{{- end -}}
{{- end -}}

{{/* Name of the server config ConfigMap. */}}
{{- define "cadence.configMapName" -}}
{{- printf "%s-config" (include "quench-common.fullname" .) -}}
{{- end -}}

{{/*
Cassandra wiring. When cassandra.enabled the bundled subchart's ClusterIP Service is
named "<release>-cassandra". When external, everything comes from externalCassandra.
Cadence uses TWO keyspaces on the same Cassandra: the main store (keyspaces.main) and
the visibility store (keyspaces.visibility).
*/}}
{{- define "cadence.cassandra.host" -}}
{{- if .Values.cassandra.enabled -}}
{{- printf "%s-cassandra" .Release.Name -}}
{{- else -}}
{{- required "externalCassandra.host is required when cassandra.enabled=false" .Values.externalCassandra.host -}}
{{- end -}}
{{- end -}}

{{- define "cadence.cassandra.port" -}}
{{- if .Values.cassandra.enabled -}}9042{{- else -}}{{ .Values.externalCassandra.port }}{{- end -}}
{{- end -}}

{{/*
Cassandra user. Bundled: the subchart bootstraps the default cassandra/cassandra
superuser when auth is enabled, and no account when auth is disabled. External:
externalCassandra.user. May be empty (auth disabled).
*/}}
{{- define "cadence.cassandra.user" -}}
{{- if .Values.cassandra.enabled -}}
{{- if .Values.cassandra.auth.enabled -}}cassandra{{- end -}}
{{- else -}}
{{- .Values.externalCassandra.user -}}
{{- end -}}
{{- end -}}

{{/* Cassandra password literal. May be empty (auth disabled). */}}
{{- define "cadence.cassandra.password" -}}
{{- if .Values.cassandra.enabled -}}
{{- if .Values.cassandra.auth.enabled -}}cassandra{{- end -}}
{{- else -}}
{{- .Values.externalCassandra.password -}}
{{- end -}}
{{- end -}}

{{/* Whether a Cassandra password is in play (drives Secret + env injection). */}}
{{- define "cadence.cassandra.hasPassword" -}}
{{- if include "cadence.cassandra.password" . -}}true{{- end -}}
{{- end -}}

{{/* Secret + key holding the Cassandra password. */}}
{{- define "cadence.cassandra.secretName" -}}
{{- if and (not .Values.cassandra.enabled) .Values.externalCassandra.existingSecret -}}
{{- .Values.externalCassandra.existingSecret -}}
{{- else -}}
{{- include "quench-common.fullname" . -}}
{{- end -}}
{{- end -}}

{{- define "cadence.cassandra.secretPasswordKey" -}}
{{- if and (not .Values.cassandra.enabled) .Values.externalCassandra.existingSecret -}}
{{- .Values.externalCassandra.existingSecretPasswordKey -}}
{{- else -}}
cassandra-password
{{- end -}}
{{- end -}}

{{/*
Connection env shared by every schema-bootstrap init container. cadence-cassandra-tool
reads --endpoint from CASSANDRA_HOST, --port from CASSANDRA_DB_PORT, --user from
CASSANDRA_USER and --password from CASSANDRA_PASSWORD. The keyspace is NEVER set via
env (CASSANDRA_KEYSPACE) — each container passes its own -k so a single env cannot
pin every step to one keyspace. Password comes from the Secret; never echoed.
*/}}
{{- define "cadence.schemaConnEnv" -}}
- name: CASSANDRA_HOST
  value: "{{ include "cadence.cassandra.host" . }}"
- name: CASSANDRA_DB_PORT
  value: "{{ include "cadence.cassandra.port" . }}"
{{- $user := include "cadence.cassandra.user" . }}
{{- if $user }}
- name: CASSANDRA_USER
  value: "{{ $user }}"
{{- end }}
{{- if include "cadence.cassandra.hasPassword" . }}
- name: CASSANDRA_PASSWORD
  valueFrom:
    secretKeyRef:
      name: {{ include "cadence.cassandra.secretName" . }}
      key: {{ include "cadence.cassandra.secretPasswordKey" . }}
{{- end }}
{{- end -}}
