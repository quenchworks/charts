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

{{/* The Secret and key holding the DB password. With the bundled MariaDB it is the
     subchart's own Secret: copying the password into this chart's Secret cannot work on
     a first install, where lookup finds nothing and each chart generates its own. */}}
{{- define "ghost.secretName" -}}
{{- if .Values.mariadb.enabled -}}
{{- .Values.mariadb.auth.existingSecret | default (printf "%s-mariadb" .Release.Name) -}}
{{- else if .Values.externalDatabase.existingSecret -}}
{{- .Values.externalDatabase.existingSecret -}}
{{- else -}}
{{- include "quench-common.fullname" . -}}
{{- end -}}
{{- end -}}

{{- define "ghost.secretPasswordKey" -}}
{{- if and .Values.mariadb.enabled .Values.mariadb.auth.existingSecret -}}
{{- .Values.mariadb.auth.existingSecretPasswordKey | default "mariadb-password" -}}
{{- else if .Values.mariadb.enabled -}}
mariadb-password
{{- else if .Values.externalDatabase.existingSecret -}}
{{- .Values.externalDatabase.existingSecretPasswordKey -}}
{{- else -}}
db-password
{{- end -}}
{{- end -}}

{{/* Whether this chart renders its own Secret: only for an external database without
     an existingSecret. */}}
{{- define "ghost.manageSecret" -}}
{{- if and (not .Values.mariadb.enabled) (not .Values.externalDatabase.existingSecret) -}}true{{- end -}}
{{- end -}}
