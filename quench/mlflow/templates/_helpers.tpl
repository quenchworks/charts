{{- define "mlflow.serviceAccountName" -}}
{{- if .Values.serviceAccount.create -}}{{ default (include "quench-common.fullname" .) .Values.serviceAccount.name }}{{- else -}}{{ default "default" .Values.serviceAccount.name }}{{- end -}}
{{- end -}}

{{/*
Database wiring. When postgresql.enabled the bundled subchart's primary Service is
named "<release>-postgresql" (the subchart's quench-common.fullname resolves against
its own chart name "postgresql"). The bundled PostgreSQL image creates POSTGRES_USER
(= postgresql.auth.username) as the SUPERUSER and only creates the application database
when it differs from POSTGRES_USER — so the user (mlflowuser) and database (mlflow) MUST
be distinct. MLflow connects to the backend store with that single role. When external,
the connection details come from externalDatabase.*.
*/}}
{{- define "mlflow.db.host" -}}
{{- if .Values.postgresql.enabled -}}
{{- printf "%s-postgresql" .Release.Name -}}
{{- else -}}
{{- required "externalDatabase.host is required when postgresql.enabled=false" .Values.externalDatabase.host -}}
{{- end -}}
{{- end -}}

{{- define "mlflow.db.port" -}}
{{- if .Values.postgresql.enabled -}}5432{{- else -}}{{ .Values.externalDatabase.port }}{{- end -}}
{{- end -}}

{{- define "mlflow.db.name" -}}
{{- if .Values.postgresql.enabled -}}{{ .Values.postgresql.auth.database }}{{- else -}}{{ .Values.externalDatabase.database }}{{- end -}}
{{- end -}}

{{- define "mlflow.db.user" -}}
{{- if .Values.postgresql.enabled -}}{{ .Values.postgresql.auth.username }}{{- else -}}{{ .Values.externalDatabase.user }}{{- end -}}
{{- end -}}

{{/* sslmode appended to the SQLAlchemy DSN query string. */}}
{{- define "mlflow.db.sslMode" -}}
{{- if .Values.postgresql.enabled -}}disable{{- else -}}{{ .Values.externalDatabase.sslMode }}{{- end -}}
{{- end -}}

{{/* Name of the Secret holding the backend-store-uri (and DB password). */}}
{{- define "mlflow.secretName" -}}
{{- if and (not .Values.postgresql.enabled) .Values.externalDatabase.existingSecret -}}
{{- .Values.externalDatabase.existingSecret -}}
{{- else -}}
{{- include "quench-common.fullname" . -}}
{{- end -}}
{{- end -}}

{{/* Whether this chart renders its own managed Secret (holding the assembled DSN). */}}
{{- define "mlflow.manageSecret" -}}
{{- if or .Values.postgresql.enabled (not .Values.externalDatabase.existingSecret) -}}true{{- end -}}
{{- end -}}

{{/* Artifact destination URI passed via --artifacts-destination. */}}
{{- define "mlflow.artifactRoot" -}}
{{- if .Values.artifactRoot -}}
{{- .Values.artifactRoot -}}
{{- else if .Values.persistence.enabled -}}
{{- printf "file://%s" .Values.persistence.mountPath -}}
{{- else -}}
{{- fail "set artifactRoot (e.g. s3://bucket/path) when persistence.enabled=false" -}}
{{- end -}}
{{- end -}}
