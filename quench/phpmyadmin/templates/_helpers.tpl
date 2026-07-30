{{- define "phpmyadmin.serviceAccountName" -}}
{{- if .Values.serviceAccount.create -}}{{ default (include "quench-common.fullname" .) .Values.serviceAccount.name }}{{- else -}}{{ default "default" .Values.serviceAccount.name }}{{- end -}}
{{- end -}}

{{/*
Database wiring. phpMyAdmin is a CLIENT: it only needs an address, and with cookie auth the
user supplies the credentials. Resolution order for the server list:
  1. phpmyadmin.hosts (explicit, comma-separated -> a dropdown in the login form)
  2. the bundled MariaDB subchart's primary Service, "<release>-mariadb"
  3. externalDatabase.host
*/}}
{{- define "phpmyadmin.db.hosts" -}}
{{- if .Values.phpmyadmin.hosts -}}
{{- .Values.phpmyadmin.hosts -}}
{{- else if .Values.mariadb.enabled -}}
{{- printf "%s-mariadb" .Release.Name -}}
{{- else -}}
{{- required "set phpmyadmin.hosts or externalDatabase.host (or enable the bundled mariadb)" .Values.externalDatabase.host -}}
{{- end -}}
{{- end -}}

{{- define "phpmyadmin.db.port" -}}
{{- if and (not .Values.phpmyadmin.hosts) .Values.mariadb.enabled -}}3306{{- else -}}{{ .Values.externalDatabase.port | default 3306 }}{{- end -}}
{{- end -}}

{{/* Name of the Secret holding the blowfish secret. */}}
{{- define "phpmyadmin.secretName" -}}
{{- if .Values.phpmyadmin.existingSecret -}}
{{- .Values.phpmyadmin.existingSecret -}}
{{- else -}}
{{- include "quench-common.fullname" . -}}
{{- end -}}
{{- end -}}

{{- define "phpmyadmin.secretBlowfishKey" -}}
{{- if .Values.phpmyadmin.existingSecret -}}
{{- .Values.phpmyadmin.existingSecretBlowfishKey -}}
{{- else -}}
blowfish-secret
{{- end -}}
{{- end -}}
