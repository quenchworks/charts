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

{{/* The Secret and key holding the DB password. With the bundled MySQL it is the
     subchart's own Secret: copying the password into this chart's Secret cannot work on
     a first install, where lookup finds nothing and each chart generates its own. */}}
{{- define "drupal.secretName" -}}
{{- if .Values.mysql.enabled -}}
{{- .Values.mysql.auth.existingSecret | default (printf "%s-mysql" .Release.Name) -}}
{{- else if .Values.externalDatabase.existingSecret -}}
{{- .Values.externalDatabase.existingSecret -}}
{{- else -}}
{{- include "quench-common.fullname" . -}}
{{- end -}}
{{- end -}}

{{- define "drupal.secretPasswordKey" -}}
{{- if and .Values.mysql.enabled .Values.mysql.auth.existingSecret -}}
{{- .Values.mysql.auth.existingSecretPasswordKey | default "mysql-password" -}}
{{- else if .Values.mysql.enabled -}}
mysql-password
{{- else if .Values.externalDatabase.existingSecret -}}
{{- .Values.externalDatabase.existingSecretPasswordKey -}}
{{- else -}}
db-password
{{- end -}}
{{- end -}}

{{/* Whether the managed Secret carries the DB password (it always carries the hash salt):
     only for an external database without an existingSecret. */}}
{{- define "drupal.manageDbPassword" -}}
{{- if and (not .Values.mysql.enabled) (not .Values.externalDatabase.existingSecret) -}}true{{- end -}}
{{- end -}}
