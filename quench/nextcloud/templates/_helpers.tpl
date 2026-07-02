{{- define "nextcloud.serviceAccountName" -}}
{{- if .Values.serviceAccount.create -}}{{ default (include "quench-common.fullname" .) .Values.serviceAccount.name }}{{- else -}}{{ default "default" .Values.serviceAccount.name }}{{- end -}}
{{- end -}}

{{/*
Database wiring. When mariadb.enabled the bundled subchart's primary Service is named
"<release>-mariadb" (the subchart's quench-common.fullname resolves against its own chart
name "mariadb"). The MariaDB image creates auth.database and the auth.username/password on
first init, so Nextcloud is installed against that database with that user. When external,
the connection details come from externalDatabase.*. The install initContainer passes
these to `occ maintenance:install`; the password is injected from a Secret.
*/}}
{{- define "nextcloud.db.host" -}}
{{- if .Values.mariadb.enabled -}}
{{- printf "%s-mariadb" .Release.Name -}}
{{- else -}}
{{- required "externalDatabase.host is required when mariadb.enabled=false" .Values.externalDatabase.host -}}
{{- end -}}
{{- end -}}

{{- define "nextcloud.db.port" -}}
{{- if .Values.mariadb.enabled -}}3306{{- else -}}{{ .Values.externalDatabase.port }}{{- end -}}
{{- end -}}

{{- define "nextcloud.db.name" -}}
{{- if .Values.mariadb.enabled -}}{{ required "mariadb.auth.database is required" .Values.mariadb.auth.database }}{{- else -}}{{ .Values.externalDatabase.database }}{{- end -}}
{{- end -}}

{{- define "nextcloud.db.user" -}}
{{- if .Values.mariadb.enabled -}}{{ required "mariadb.auth.username is required" .Values.mariadb.auth.username }}{{- else -}}{{ .Values.externalDatabase.user }}{{- end -}}
{{- end -}}

{{/* Name of the Secret holding the DB password. */}}
{{- define "nextcloud.secretName" -}}
{{- if and (not .Values.mariadb.enabled) .Values.externalDatabase.existingSecret -}}
{{- .Values.externalDatabase.existingSecret -}}
{{- else -}}
{{- include "quench-common.fullname" . -}}
{{- end -}}
{{- end -}}

{{/* Key in the Secret that holds the DB password. */}}
{{- define "nextcloud.secretPasswordKey" -}}
{{- if and (not .Values.mariadb.enabled) .Values.externalDatabase.existingSecret -}}
{{- .Values.externalDatabase.existingSecretPasswordKey -}}
{{- else -}}
db-password
{{- end -}}
{{- end -}}

{{/* Whether this chart renders the DB password into its managed Secret. False only when an
     external DB supplies the password through its own existingSecret. The managed Secret
     is ALWAYS rendered regardless (it also carries the Nextcloud admin-password). */}}
{{- define "nextcloud.manageDbSecret" -}}
{{- if or .Values.mariadb.enabled (not .Values.externalDatabase.existingSecret) -}}true{{- end -}}
{{- end -}}
