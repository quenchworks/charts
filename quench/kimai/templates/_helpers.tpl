{{/* Every port Kimai listens on, as {name, port, servicePort, protocol}: container, Service and NetworkPolicy. */}}
{{- define "kimai.ports" -}}
{{- toJson (list (dict "name" (ternary "https" "http" (eq (include "quench-common.tls.enabled" .) "true")) "port" 8080 "servicePort" (int .Values.service.port) "protocol" "TCP")) -}}
{{- end -}}

{{- define "kimai.pvcName" -}}
{{- .Values.persistence.existingClaim | default (include "quench-common.fullname" .) -}}
{{- end -}}

{{- define "kimai.secretName" -}}
{{- include "quench-common.fullname" . -}}
{{- end -}}

{{- define "kimai.appSecretName" -}}
{{- .Values.appSecret.existingSecret | default (include "quench-common.fullname" .) -}}
{{- end -}}

{{/*
Database wiring. The bundled subchart's Service and Secret are both "<release>-mariadb" (its
quench-common.fullname resolves against its own chart name), unless mariadb.auth.existingSecret names
another Secret.
*/}}
{{- define "kimai.db.host" -}}
{{- if .Values.mariadb.enabled -}}
{{- printf "%s-mariadb" .Release.Name -}}
{{- else -}}
{{- required "externalDatabase.host is required when mariadb.enabled=false" .Values.externalDatabase.host -}}
{{- end -}}
{{- end -}}

{{- define "kimai.db.secretName" -}}
{{- if .Values.mariadb.enabled -}}
{{- .Values.mariadb.auth.existingSecret | default (printf "%s-mariadb" .Release.Name) -}}
{{- else if .Values.externalDatabase.existingSecret -}}
{{- .Values.externalDatabase.existingSecret -}}
{{- else -}}
{{- include "quench-common.fullname" . -}}
{{- end -}}
{{- end -}}

{{- define "kimai.db.secretKey" -}}
{{- if .Values.mariadb.enabled -}}
{{- if .Values.mariadb.auth.existingSecret -}}{{ .Values.mariadb.auth.existingSecretPasswordKey | default "mariadb-password" }}{{- else -}}mariadb-password{{- end -}}
{{- else if .Values.externalDatabase.existingSecret -}}
{{- .Values.externalDatabase.existingSecretPasswordKey -}}
{{- else -}}
db-password
{{- end -}}
{{- end -}}

{{/* APP_SECRET, the admin and DATABASE_URL (the password through env expansion of DB_PASSWORD). */}}
{{- define "kimai.env" -}}
- name: APP_SECRET
  valueFrom:
    secretKeyRef: { name: {{ include "kimai.appSecretName" . }}, key: app-secret }
- { name: ADMIN_USER, value: {{ .Values.admin.username | quote }} }
- { name: ADMIN_EMAIL, value: {{ .Values.admin.email | quote }} }
- name: ADMIN_PASSWORD
  valueFrom:
    secretKeyRef: { name: {{ include "kimai.secretName" . }}, key: admin-password }
- name: DB_PASSWORD
  valueFrom:
    secretKeyRef: { name: {{ include "kimai.db.secretName" . }}, key: {{ include "kimai.db.secretKey" . }} }
{{- if .Values.mariadb.enabled }}
{{- /* serverVersion of the bundled mariadb subchart (0.0.28 ships MariaDB 12.3.3): move it with the subchart */}}
- { name: DATABASE_URL, value: {{ printf "mysql://%s:$(DB_PASSWORD)@%s:3306/%s?charset=utf8mb4&serverVersion=12.3.3-MariaDB" .Values.mariadb.auth.username (include "kimai.db.host" .) .Values.mariadb.auth.database | quote }} }
{{- else }}
- { name: DATABASE_URL, value: {{ printf "mysql://%s:$(DB_PASSWORD)@%s:%v/%s?charset=utf8mb4&serverVersion=%s" .Values.externalDatabase.user (include "kimai.db.host" .) .Values.externalDatabase.port .Values.externalDatabase.database .Values.externalDatabase.serverVersion | quote }} }
{{- end }}
{{- range $k, $v := .Values.settings }}
- { name: {{ $k }}, value: {{ $v | quote }} }
{{- end }}
{{- end -}}
