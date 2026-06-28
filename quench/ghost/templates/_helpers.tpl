{{- define "ghost.serviceAccountName" -}}
{{- if .Values.serviceAccount.create -}}{{ default (include "quench-common.fullname" .) .Values.serviceAccount.name }}{{- else -}}{{ default "default" .Values.serviceAccount.name }}{{- end -}}
{{- end -}}

{{/*
Database wiring. When mariadb.enabled the bundled subchart's primary Service is named
"<release>-mariadb" (the subchart's quench-common.fullname resolves against its own chart
name "mariadb"). The MariaDB image creates auth.database and the auth.username/password
on first init, so Ghost connects to that database with that user. When external, the
connection details come from externalDatabase.*. Ghost reads these as the
database__connection__* env keys; the password is injected from the managed Secret.
*/}}
{{- define "ghost.db.host" -}}
{{- if .Values.mariadb.enabled -}}
{{- printf "%s-mariadb" .Release.Name -}}
{{- else -}}
{{- required "externalDatabase.host is required when mariadb.enabled=false" .Values.externalDatabase.host -}}
{{- end -}}
{{- end -}}

{{- define "ghost.db.port" -}}
{{- if .Values.mariadb.enabled -}}3306{{- else -}}{{ .Values.externalDatabase.port }}{{- end -}}
{{- end -}}

{{- define "ghost.db.name" -}}
{{- if .Values.mariadb.enabled -}}{{ required "mariadb.auth.database is required" .Values.mariadb.auth.database }}{{- else -}}{{ .Values.externalDatabase.database }}{{- end -}}
{{- end -}}

{{- define "ghost.db.user" -}}
{{- if .Values.mariadb.enabled -}}{{ required "mariadb.auth.username is required" .Values.mariadb.auth.username }}{{- else -}}{{ .Values.externalDatabase.user }}{{- end -}}
{{- end -}}

{{/* Name of the Secret holding the Ghost DB password. */}}
{{- define "ghost.secretName" -}}
{{- if and (not .Values.mariadb.enabled) .Values.externalDatabase.existingSecret -}}
{{- .Values.externalDatabase.existingSecret -}}
{{- else -}}
{{- include "quench-common.fullname" . -}}
{{- end -}}
{{- end -}}

{{/* Key in the Secret that holds the DB password. */}}
{{- define "ghost.secretPasswordKey" -}}
{{- if and (not .Values.mariadb.enabled) .Values.externalDatabase.existingSecret -}}
{{- .Values.externalDatabase.existingSecretPasswordKey -}}
{{- else -}}
db-password
{{- end -}}
{{- end -}}

{{/* Whether this chart renders its own managed Secret (holding the DB password). */}}
{{- define "ghost.manageSecret" -}}
{{- if or .Values.mariadb.enabled (not .Values.externalDatabase.existingSecret) -}}true{{- end -}}
{{- end -}}
