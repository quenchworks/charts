{{- define "friendica.serviceAccountName" -}}
{{- if .Values.serviceAccount.create -}}{{ default (include "quench-common.fullname" .) .Values.serviceAccount.name }}{{- else -}}{{ default "default" .Values.serviceAccount.name }}{{- end -}}
{{- end -}}

{{/*
Database wiring. The bundled subchart's Service and Secret are both "<release>-mariadb"
(its quench-common.fullname resolves against its own chart name), unless
mariadb.auth.existingSecret names another Secret.
*/}}
{{- define "friendica.db.host" -}}
{{- if .Values.mariadb.enabled -}}
{{- printf "%s-mariadb" .Release.Name -}}
{{- else -}}
{{- required "externalDatabase.host is required when mariadb.enabled=false" .Values.externalDatabase.host -}}
{{- end -}}
{{- end -}}

{{- define "friendica.db.port" -}}
{{- if .Values.mariadb.enabled -}}3306{{- else -}}{{ .Values.externalDatabase.port }}{{- end -}}
{{- end -}}

{{- define "friendica.db.name" -}}
{{- if .Values.mariadb.enabled -}}{{ required "mariadb.auth.database is required" .Values.mariadb.auth.database }}{{- else -}}{{ .Values.externalDatabase.database }}{{- end -}}
{{- end -}}

{{- define "friendica.db.user" -}}
{{- if .Values.mariadb.enabled -}}{{ required "mariadb.auth.username is required" .Values.mariadb.auth.username }}{{- else -}}{{ .Values.externalDatabase.user }}{{- end -}}
{{- end -}}

{{- define "friendica.db.secretName" -}}
{{- if .Values.mariadb.enabled -}}
{{- .Values.mariadb.auth.existingSecret | default (printf "%s-mariadb" .Release.Name) -}}
{{- else if .Values.externalDatabase.existingSecret -}}
{{- .Values.externalDatabase.existingSecret -}}
{{- else -}}
{{- include "quench-common.fullname" . -}}
{{- end -}}
{{- end -}}

{{- define "friendica.db.secretKey" -}}
{{- if .Values.mariadb.enabled -}}
{{- if .Values.mariadb.auth.existingSecret -}}{{ .Values.mariadb.auth.existingSecretPasswordKey | default "mariadb-password" }}{{- else -}}mariadb-password{{- end -}}
{{- else if .Values.externalDatabase.existingSecret -}}
{{- .Values.externalDatabase.existingSecretPasswordKey -}}
{{- else -}}
db-password
{{- end -}}
{{- end -}}

{{/*
The public base URL Friendica writes into every link and federation id. Defaults to the
first ingress host, else the in-cluster Service address (fine for a test, not for
federation).
*/}}
{{- define "friendica.url" -}}
{{- if .Values.friendica.url -}}
{{- .Values.friendica.url | trimSuffix "/" -}}
{{- else if and .Values.ingress.enabled .Values.ingress.hosts -}}
{{- printf "%s://%s" (ternary "https" "http" (gt (len .Values.ingress.tls) 0)) (index .Values.ingress.hosts 0).host -}}
{{- else -}}
{{- printf "http://%s:%v" (include "quench-common.fullname" .) .Values.service.port -}}
{{- end -}}
{{- end -}}

{{/*
Settings both containers read. Friendica maps MYSQL_* and FRIENDICA_* onto its config
(static/env.config.php) with priority over local.config.php, so a rotated DB password in
the Secret reaches the running site on the next restart.
*/}}
{{- define "friendica.env" -}}
- name: MYSQL_HOST
  value: {{ include "friendica.db.host" . | quote }}
- name: MYSQL_PORT
  value: {{ include "friendica.db.port" . | quote }}
- name: MYSQL_DATABASE
  value: {{ include "friendica.db.name" . | quote }}
- name: MYSQL_USER
  value: {{ include "friendica.db.user" . | quote }}
- name: MYSQL_PASSWORD
  valueFrom:
    secretKeyRef:
      name: {{ include "friendica.db.secretName" . }}
      key: {{ include "friendica.db.secretKey" . }}
- name: FRIENDICA_URL
  value: {{ include "friendica.url" . | quote }}
- name: FRIENDICA_ADMIN_MAIL
  value: {{ .Values.friendica.adminEmail | quote }}
- name: FRIENDICA_SITENAME
  value: {{ .Values.friendica.siteName | quote }}
- name: FRIENDICA_TZ
  value: {{ .Values.friendica.timezone | quote }}
- name: FRIENDICA_LANG
  value: {{ .Values.friendica.language | quote }}
{{- end -}}
