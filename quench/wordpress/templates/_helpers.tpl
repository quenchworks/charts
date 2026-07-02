{{- define "wordpress.serviceAccountName" -}}
{{- if .Values.serviceAccount.create -}}{{ default (include "quench-common.fullname" .) .Values.serviceAccount.name }}{{- else -}}{{ default "default" .Values.serviceAccount.name }}{{- end -}}
{{- end -}}

{{/*
Database wiring. When mysql.enabled the bundled subchart's primary Service is named
"<release>-mysql" (the subchart's quench-common.fullname resolves against its own chart
name "mysql"). The MySQL image creates auth.database and the auth.username/password on
first init, so WordPress connects to that database with that user. When external, the
connection details come from externalDatabase.*. wp-config.php reads these as the
WORDPRESS_DB_* env keys; the password is injected from a Secret.
*/}}
{{- define "wordpress.db.host" -}}
{{- if .Values.mysql.enabled -}}
{{- printf "%s-mysql" .Release.Name -}}
{{- else -}}
{{- required "externalDatabase.host is required when mysql.enabled=false" .Values.externalDatabase.host -}}
{{- end -}}
{{- end -}}

{{- define "wordpress.db.port" -}}
{{- if .Values.mysql.enabled -}}3306{{- else -}}{{ .Values.externalDatabase.port }}{{- end -}}
{{- end -}}

{{- define "wordpress.db.name" -}}
{{- if .Values.mysql.enabled -}}{{ required "mysql.auth.database is required" .Values.mysql.auth.database }}{{- else -}}{{ .Values.externalDatabase.database }}{{- end -}}
{{- end -}}

{{- define "wordpress.db.user" -}}
{{- if .Values.mysql.enabled -}}{{ required "mysql.auth.username is required" .Values.mysql.auth.username }}{{- else -}}{{ .Values.externalDatabase.user }}{{- end -}}
{{- end -}}

{{/* Name of the Secret holding the WordPress DB password. */}}
{{- define "wordpress.secretName" -}}
{{- if and (not .Values.mysql.enabled) .Values.externalDatabase.existingSecret -}}
{{- .Values.externalDatabase.existingSecret -}}
{{- else -}}
{{- include "quench-common.fullname" . -}}
{{- end -}}
{{- end -}}

{{/* Key in the Secret that holds the DB password. */}}
{{- define "wordpress.secretPasswordKey" -}}
{{- if and (not .Values.mysql.enabled) .Values.externalDatabase.existingSecret -}}
{{- .Values.externalDatabase.existingSecretPasswordKey -}}
{{- else -}}
db-password
{{- end -}}
{{- end -}}

{{/* Whether the managed Secret carries the DB password (it always carries the auth salts). */}}
{{- define "wordpress.manageDbPassword" -}}
{{- if or .Values.mysql.enabled (not .Values.externalDatabase.existingSecret) -}}true{{- end -}}
{{- end -}}

{{/* WordPress auth key/salt names. Rendered once into the managed Secret and read back as
     WORDPRESS_<NAME> env vars by wp-config.php. Secret keys are the lower-kebab form. */}}
{{- define "wordpress.saltNames" -}}
AUTH_KEY SECURE_AUTH_KEY LOGGED_IN_KEY NONCE_KEY AUTH_SALT SECURE_AUTH_SALT LOGGED_IN_SALT NONCE_SALT
{{- end -}}
