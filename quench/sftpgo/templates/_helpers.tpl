{{/* Every port SFTPGo listens on, as {name, port, servicePort, protocol}: container, Service and NetworkPolicy. */}}
{{- define "sftpgo.ports" -}}
{{- $web := ternary "https" "http" (eq (include "quench-common.tls.enabled" .) "true") -}}
{{- toJson (list
  (dict "name" $web "port" 8080 "servicePort" (int .Values.service.port) "protocol" "TCP")
  (dict "name" "sftp" "port" 2022 "servicePort" (int .Values.service.sftpPort) "protocol" "TCP")) -}}
{{- end -}}

{{- define "sftpgo.pvcName" -}}
{{- .Values.persistence.existingClaim | default (include "quench-common.fullname" .) -}}
{{- end -}}

{{- define "sftpgo.secretName" -}}
{{- .Values.admin.existingSecret | default (include "quench-common.fullname" .) -}}
{{- end -}}

{{/* The app environment. */}}
{{- define "sftpgo.env" -}}
# the first start creates the admin from these; later starts leave an existing admin alone
- { name: SFTPGO_DATA_PROVIDER__CREATE_DEFAULT_ADMIN, value: "true" }
- { name: SFTPGO_DEFAULT_ADMIN_USERNAME, value: {{ .Values.admin.username | quote }} }
- name: SFTPGO_DEFAULT_ADMIN_PASSWORD
  valueFrom:
    secretKeyRef:
      name: {{ include "sftpgo.secretName" . }}
      key: admin-password
# one volume holds the database, the host keys, the users' files and the backups
- { name: SFTPGO_DATA_PROVIDER__USERS_BASE_DIR, value: /var/lib/sftpgo/data }
- { name: SFTPGO_DATA_PROVIDER__BACKUPS_PATH, value: /var/lib/sftpgo/backups }
{{- if include "quench-common.tls.enabled" . }}
# SFTPGo serves the web admin, web client and API over HTTPS from the PEM pair at /tls
- { name: SFTPGO_HTTPD__BINDINGS__0__ENABLE_HTTPS, value: "true" }
- { name: SFTPGO_HTTPD__CERTIFICATE_FILE, value: /tls/tls.crt }
- { name: SFTPGO_HTTPD__CERTIFICATE_KEY_FILE, value: /tls/tls.key }
{{- end }}
{{- range $k, $v := .Values.settings }}
- { name: {{ $k }}, value: {{ $v | quote }} }
{{- end }}
{{ include "quench-common.extraEnvVars" . }}
{{- end -}}
