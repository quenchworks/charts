{{- define "drupal.serviceAccountName" -}}
{{- if .Values.serviceAccount.create -}}{{ default (include "quench-common.fullname" .) .Values.serviceAccount.name }}{{- else -}}{{ default "default" .Values.serviceAccount.name }}{{- end -}}
{{- end -}}

{{/*
Database wiring. When mysql.enabled the bundled subchart's primary Service is named
"<release>-mysql" (the subchart's quench-common.fullname resolves against its own chart name
"mysql"). The MySQL image creates auth.database and the auth.username/password on first
init, so Drupal connects to that database with that user. When external, the connection
details come from externalDatabase.*. settings.php reads these as the DRUPAL_DB_* env keys;
the password is injected from a Secret.
*/}}
{{- define "drupal.db.host" -}}
{{- if .Values.mysql.enabled -}}
{{- printf "%s-mysql" .Release.Name -}}
{{- else -}}
{{- required "externalDatabase.host is required when mysql.enabled=false" .Values.externalDatabase.host -}}
{{- end -}}
{{- end -}}

{{- define "drupal.db.port" -}}
{{- if .Values.mysql.enabled -}}3306{{- else -}}{{ .Values.externalDatabase.port }}{{- end -}}
{{- end -}}

{{- define "drupal.db.name" -}}
{{- if .Values.mysql.enabled -}}{{ required "mysql.auth.database is required" .Values.mysql.auth.database }}{{- else -}}{{ .Values.externalDatabase.database }}{{- end -}}
{{- end -}}

{{- define "drupal.db.user" -}}
{{- if .Values.mysql.enabled -}}{{ required "mysql.auth.username is required" .Values.mysql.auth.username }}{{- else -}}{{ .Values.externalDatabase.user }}{{- end -}}
{{- end -}}

{{/* Name of the Secret holding the Drupal DB password. */}}
{{- define "drupal.secretName" -}}
{{- if and (not .Values.mysql.enabled) .Values.externalDatabase.existingSecret -}}
{{- .Values.externalDatabase.existingSecret -}}
{{- else -}}
{{- include "quench-common.fullname" . -}}
{{- end -}}
{{- end -}}

{{/* Key in the Secret that holds the DB password. */}}
{{- define "drupal.secretPasswordKey" -}}
{{- if and (not .Values.mysql.enabled) .Values.externalDatabase.existingSecret -}}
{{- .Values.externalDatabase.existingSecretPasswordKey -}}
{{- else -}}
db-password
{{- end -}}
{{- end -}}

{{/* Whether the managed Secret carries the DB password (it always carries the hash salt). */}}
{{- define "drupal.manageDbPassword" -}}
{{- if or .Values.mysql.enabled (not .Values.externalDatabase.existingSecret) -}}true{{- end -}}
{{- end -}}
