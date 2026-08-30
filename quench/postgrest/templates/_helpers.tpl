{{- define "postgrest.serviceAccountName" -}}
{{- if .Values.serviceAccount.create -}}{{ default (include "quench-common.fullname" .) .Values.serviceAccount.name }}{{- else -}}{{ default "default" .Values.serviceAccount.name }}{{- end -}}
{{- end -}}

{{/*
Hostname of the database. With the bundled subchart the Service is named
"<release>-postgresql" (the subchart reuses quench-common.fullname with chart
name "postgresql"); otherwise it is the externally provided host.
*/}}
{{- define "postgrest.dbHost" -}}
{{- if .Values.postgresql.enabled -}}
{{- printf "%s-postgresql" .Release.Name -}}
{{- else -}}
{{- required "externalDatabase.host is required when postgresql.enabled=false" .Values.externalDatabase.host -}}
{{- end -}}
{{- end -}}

{{/* Full PGRST_DB_URI connection string. */}}
{{- define "postgrest.databaseURI" -}}
{{- if .Values.postgresql.enabled -}}
{{- $user := .Values.postgresql.auth.username -}}
{{- $pass := required "postgresql.auth.password is required (it is shared with PGRST_DB_URI)" .Values.postgresql.auth.password -}}
{{- $db := .Values.postgresql.auth.database -}}
{{- printf "postgres://%s:%s@%s:5432/%s?sslmode=disable" (urlquery $user) (urlquery $pass) (include "postgrest.dbHost" .) $db -}}
{{- else -}}
{{- $user := .Values.externalDatabase.user -}}
{{- $pass := .Values.externalDatabase.password -}}
{{- $db := .Values.externalDatabase.database -}}
{{- $port := .Values.externalDatabase.port | toString -}}
{{- printf "postgres://%s:%s@%s:%s/%s?sslmode=%s" (urlquery $user) (urlquery $pass) (include "postgrest.dbHost" .) $port $db .Values.externalDatabase.sslmode -}}
{{- end -}}
{{- end -}}

{{/* True when the chart renders the URI itself rather than reusing an existing Secret. */}}
{{- define "postgrest.ownsURI" -}}
{{- if or .Values.postgresql.enabled (not .Values.externalDatabase.existingSecret) -}}true{{- end -}}
{{- end -}}

{{/* True when the chart stores the JWT secret itself. */}}
{{- define "postgrest.ownsJWT" -}}
{{- if and .Values.jwt.secret (not .Values.jwt.existingSecret) -}}true{{- end -}}
{{- end -}}

{{/* Whether this chart creates a Secret at all. */}}
{{- define "postgrest.createsSecret" -}}
{{- if or (include "postgrest.ownsURI" .) (include "postgrest.ownsJWT" .) -}}true{{- end -}}
{{- end -}}

{{/* Secret + key holding the database URI consumed by the pod. */}}
{{- define "postgrest.dbSecretName" -}}
{{- if include "postgrest.ownsURI" . -}}
{{- include "quench-common.fullname" . -}}
{{- else -}}
{{- .Values.externalDatabase.existingSecret -}}
{{- end -}}
{{- end -}}

{{- define "postgrest.dbURIKey" -}}
{{- if include "postgrest.ownsURI" . -}}database-uri{{- else -}}{{ .Values.externalDatabase.existingSecretURIKey }}{{- end -}}
{{- end -}}

{{/* Whether a JWT secret is in play at all. */}}
{{- define "postgrest.jwtEnabled" -}}
{{- if or .Values.jwt.secret .Values.jwt.existingSecret -}}true{{- end -}}
{{- end -}}

{{/* Secret + key holding the JWT secret consumed by the pod. */}}
{{- define "postgrest.jwtSecretName" -}}
{{- if .Values.jwt.existingSecret -}}{{ .Values.jwt.existingSecret }}{{- else -}}{{ include "quench-common.fullname" . }}{{- end -}}
{{- end -}}

{{- define "postgrest.jwtSecretKey" -}}
{{- if .Values.jwt.existingSecret -}}{{ .Values.jwt.existingSecretKey }}{{- else -}}jwt-secret{{- end -}}
{{- end -}}
