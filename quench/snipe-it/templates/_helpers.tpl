{{/* Every port Snipe-IT listens on, as {name, port, servicePort, protocol}: container, Service and NetworkPolicy. */}}
{{- define "snipe-it.ports" -}}
{{- toJson (list (dict "name" (ternary "https" "http" (eq (include "quench-common.tls.enabled" .) "true")) "port" 8080 "servicePort" (int .Values.service.port) "protocol" "TCP")) -}}
{{- end -}}

{{- define "snipe-it.pvcName" -}}
{{- .Values.persistence.existingClaim | default (include "quench-common.fullname" .) -}}
{{- end -}}

{{- define "snipe-it.secretName" -}}
{{- include "quench-common.fullname" . -}}
{{- end -}}

{{- define "snipe-it.appKeySecretName" -}}
{{- .Values.appKey.existingSecret | default (include "quench-common.fullname" .) -}}
{{- end -}}

{{/*
Database wiring. The bundled subchart's Service and Secret are both "<release>-mariadb" (its
quench-common.fullname resolves against its own chart name), unless mariadb.auth.existingSecret names
another Secret.
*/}}
{{- define "snipe-it.db.host" -}}
{{- if .Values.mariadb.enabled -}}
{{- printf "%s-mariadb" .Release.Name -}}
{{- else -}}
{{- required "externalDatabase.host is required when mariadb.enabled=false" .Values.externalDatabase.host -}}
{{- end -}}
{{- end -}}

{{- define "snipe-it.db.secretName" -}}
{{- if .Values.mariadb.enabled -}}
{{- .Values.mariadb.auth.existingSecret | default (printf "%s-mariadb" .Release.Name) -}}
{{- else if .Values.externalDatabase.existingSecret -}}
{{- .Values.externalDatabase.existingSecret -}}
{{- else -}}
{{- include "quench-common.fullname" . -}}
{{- end -}}
{{- end -}}

{{- define "snipe-it.db.secretKey" -}}
{{- if .Values.mariadb.enabled -}}
{{- if .Values.mariadb.auth.existingSecret -}}{{ .Values.mariadb.auth.existingSecretPasswordKey | default "mariadb-password" }}{{- else -}}mariadb-password{{- end -}}
{{- else if .Values.externalDatabase.existingSecret -}}
{{- .Values.externalDatabase.existingSecretPasswordKey -}}
{{- else -}}
db-password
{{- end -}}
{{- end -}}

{{/* APP_KEY, the admin, the site name and DB_* for Snipe-IT. */}}
{{- define "snipe-it.env" -}}
- name: APP_KEY
  valueFrom:
    secretKeyRef: { name: {{ include "snipe-it.appKeySecretName" . }}, key: app-key }
{{- with .Values.appURL }}
- { name: APP_URL, value: {{ . | quote }} }
{{- end }}
- { name: SITE_NAME, value: {{ .Values.siteName | quote }} }
- { name: ADMIN_USER, value: {{ .Values.admin.username | quote }} }
- { name: ADMIN_EMAIL, value: {{ .Values.admin.email | quote }} }
- name: ADMIN_PASSWORD
  valueFrom:
    secretKeyRef: { name: {{ include "snipe-it.secretName" . }}, key: admin-password }
- { name: DB_CONNECTION, value: mysql }
- { name: DB_HOST, value: {{ include "snipe-it.db.host" . | quote }} }
- { name: DB_PORT, value: {{ ternary "3306" (toString .Values.externalDatabase.port) .Values.mariadb.enabled | quote }} }
- { name: DB_DATABASE, value: {{ ternary .Values.mariadb.auth.database .Values.externalDatabase.database .Values.mariadb.enabled | quote }} }
- { name: DB_USERNAME, value: {{ ternary .Values.mariadb.auth.username .Values.externalDatabase.user .Values.mariadb.enabled | quote }} }
- name: DB_PASSWORD
  valueFrom:
    secretKeyRef: { name: {{ include "snipe-it.db.secretName" . }}, key: {{ include "snipe-it.db.secretKey" . }} }
{{- range $k, $v := .Values.settings }}
- { name: {{ $k }}, value: {{ $v | quote }} }
{{- end }}
{{- end -}}
