{{/* Every port the pod listens on, as {name, port, protocol}: container and NetworkPolicy.
     https is the TLS sidecar, only with tls.enabled. */}}
{{- define "bookstack.ports" -}}
{{- $p := list (dict "name" "http" "port" 8080 "protocol" "TCP") -}}
{{- if include "quench-common.tls.enabled" . }}{{ $p = append $p (dict "name" "https" "port" 8443 "protocol" "TCP") }}{{ end -}}
{{- toJson $p -}}
{{- end -}}

{{- define "bookstack.pvcName" -}}
{{- .Values.persistence.existingClaim | default (include "quench-common.fullname" .) -}}
{{- end -}}

{{/*
Database wiring. The bundled subchart's Service and Secret are both "<release>-mariadb"
(its quench-common.fullname resolves against its own chart name), unless
mariadb.auth.existingSecret names another Secret.
*/}}
{{- define "bookstack.db.host" -}}
{{- if .Values.mariadb.enabled -}}
{{- printf "%s-mariadb" .Release.Name -}}
{{- else -}}
{{- required "externalDatabase.host is required when mariadb.enabled=false" .Values.externalDatabase.host -}}
{{- end -}}
{{- end -}}

{{- define "bookstack.db.port" -}}
{{- if .Values.mariadb.enabled -}}3306{{- else -}}{{ .Values.externalDatabase.port }}{{- end -}}
{{- end -}}

{{- define "bookstack.db.name" -}}
{{- if .Values.mariadb.enabled -}}{{ required "mariadb.auth.database is required" .Values.mariadb.auth.database }}{{- else -}}{{ .Values.externalDatabase.database }}{{- end -}}
{{- end -}}

{{- define "bookstack.db.user" -}}
{{- if .Values.mariadb.enabled -}}{{ required "mariadb.auth.username is required" .Values.mariadb.auth.username }}{{- else -}}{{ .Values.externalDatabase.user }}{{- end -}}
{{- end -}}

{{- define "bookstack.db.secretName" -}}
{{- if .Values.mariadb.enabled -}}
{{- .Values.mariadb.auth.existingSecret | default (printf "%s-mariadb" .Release.Name) -}}
{{- else if .Values.externalDatabase.existingSecret -}}
{{- .Values.externalDatabase.existingSecret -}}
{{- else -}}
{{- include "quench-common.fullname" . -}}
{{- end -}}
{{- end -}}

{{- define "bookstack.db.secretKey" -}}
{{- if .Values.mariadb.enabled -}}
{{- if .Values.mariadb.auth.existingSecret -}}{{ .Values.mariadb.auth.existingSecretPasswordKey | default "mariadb-password" }}{{- else -}}mariadb-password{{- end -}}
{{- else if .Values.externalDatabase.existingSecret -}}
{{- .Values.externalDatabase.existingSecretPasswordKey -}}
{{- else -}}
db-password
{{- end -}}
{{- end -}}

{{- define "bookstack.keySecretName" -}}
{{- .Values.appKey.existingSecret | default (include "quench-common.fullname" .) -}}
{{- end -}}

{{/* DB_* for BookStack (and the prepare init container's connection check). */}}
{{- define "bookstack.dbEnv" -}}
- { name: DB_HOST, value: {{ include "bookstack.db.host" . | quote }} }
- { name: DB_PORT, value: {{ include "bookstack.db.port" . | quote }} }
- { name: DB_DATABASE, value: {{ include "bookstack.db.name" . | quote }} }
- { name: DB_USERNAME, value: {{ include "bookstack.db.user" . | quote }} }
- name: DB_PASSWORD
  valueFrom: { secretKeyRef: { name: {{ include "bookstack.db.secretName" . }}, key: {{ include "bookstack.db.secretKey" . }} } }
{{- end -}}
