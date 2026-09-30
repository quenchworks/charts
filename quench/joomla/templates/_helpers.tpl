{{- define "joomla.serviceAccountName" -}}
{{- if .Values.serviceAccount.create -}}{{ default (include "quench-common.fullname" .) .Values.serviceAccount.name }}{{- else -}}{{ default "default" .Values.serviceAccount.name }}{{- end -}}
{{- end -}}

{{/*
Database wiring. The bundled subchart's Service and Secret are both "<release>-mariadb"
(its quench-common.fullname resolves against its own chart name), unless
mariadb.auth.existingSecret names another Secret.
*/}}
{{- define "joomla.db.host" -}}
{{- if .Values.mariadb.enabled -}}
{{- printf "%s-mariadb" .Release.Name -}}
{{- else -}}
{{- required "externalDatabase.host is required when mariadb.enabled=false" .Values.externalDatabase.host -}}
{{- end -}}
{{- end -}}

{{- define "joomla.db.port" -}}
{{- if .Values.mariadb.enabled -}}3306{{- else -}}{{ .Values.externalDatabase.port }}{{- end -}}
{{- end -}}

{{- define "joomla.db.name" -}}
{{- if .Values.mariadb.enabled -}}{{ required "mariadb.auth.database is required" .Values.mariadb.auth.database }}{{- else -}}{{ .Values.externalDatabase.database }}{{- end -}}
{{- end -}}

{{- define "joomla.db.user" -}}
{{- if .Values.mariadb.enabled -}}{{ required "mariadb.auth.username is required" .Values.mariadb.auth.username }}{{- else -}}{{ .Values.externalDatabase.user }}{{- end -}}
{{- end -}}

{{- define "joomla.db.secretName" -}}
{{- if .Values.mariadb.enabled -}}
{{- .Values.mariadb.auth.existingSecret | default (printf "%s-mariadb" .Release.Name) -}}
{{- else if .Values.externalDatabase.existingSecret -}}
{{- .Values.externalDatabase.existingSecret -}}
{{- else -}}
{{- include "quench-common.fullname" . -}}
{{- end -}}
{{- end -}}

{{- define "joomla.db.secretKey" -}}
{{- if .Values.mariadb.enabled -}}
{{- if .Values.mariadb.auth.existingSecret -}}{{ .Values.mariadb.auth.existingSecretPasswordKey | default "mariadb-password" }}{{- else -}}mariadb-password{{- end -}}
{{- else if .Values.externalDatabase.existingSecret -}}
{{- .Values.externalDatabase.existingSecretPasswordKey -}}
{{- else -}}
db-password
{{- end -}}
{{- end -}}

{{- define "joomla.admin.secretName" -}}
{{- .Values.joomla.admin.existingSecret | default (include "quench-common.fullname" .) -}}
{{- end -}}

{{- define "joomla.admin.secretKey" -}}
{{- if .Values.joomla.admin.existingSecret -}}{{ .Values.joomla.admin.existingSecretPasswordKey }}{{- else -}}admin-password{{- end -}}
{{- end -}}
