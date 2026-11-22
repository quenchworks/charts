{{/* The one port: the API and UI on 8080, HTTPS on the same port with TLS. */}}
{{- define "bloodhound.ports" -}}
{{- toJson (list (dict "name" (ternary "https" "http" (eq (include "quench-common.tls.enabled" .) "true")) "port" 8080 "servicePort" (int .Values.service.port) "protocol" "TCP")) -}}
{{- end -}}

{{- define "bloodhound.secretName" -}}
{{- .Values.secret.existingSecret | default (include "quench-common.fullname" .) -}}
{{- end -}}

{{/* Settings as bhe_* variables (each overrides a key of /bloodhound.config.json). The database connection string is
     assembled by the kubelet ($(VAR) expansion), so the password never sits in the pod spec. */}}
{{- define "bloodhound.env" -}}
{{- $tls := eq (include "quench-common.tls.enabled" .) "true" -}}
{{- if .Values.postgresql.enabled }}
- { name: DB_HOST, value: {{ printf "%s-postgresql" .Release.Name | quote }} }
- { name: DB_NAME, value: {{ .Values.postgresql.auth.database | quote }} }
- { name: DB_USER, value: {{ .Values.postgresql.auth.username | quote }} }
- name: DB_PASS
  valueFrom:
    secretKeyRef: { name: {{ printf "%s-postgresql" .Release.Name }}, key: postgres-password }
{{- else }}
- { name: DB_HOST, value: {{ required "externalDatabase.host is required when postgresql.enabled=false" .Values.externalDatabase.host | quote }} }
- { name: DB_NAME, value: {{ .Values.externalDatabase.database | quote }} }
- { name: DB_USER, value: {{ .Values.externalDatabase.username | quote }} }
- name: DB_PASS
  valueFrom:
    secretKeyRef: { name: {{ required "externalDatabase.existingSecret is required when postgresql.enabled=false" .Values.externalDatabase.existingSecret }}, key: {{ .Values.externalDatabase.existingSecretPasswordKey }} }
{{- end }}
- { name: bhe_database_connection, value: "user=$(DB_USER) password=$(DB_PASS) dbname=$(DB_NAME) host=$(DB_HOST)" }
- { name: bhe_graph_driver, value: pg }
- { name: bhe_root_url, value: {{ .Values.rootURL | default (printf "%s://%s.%s:%d/" (ternary "https" "http" $tls) (include "quench-common.fullname" .) .Release.Namespace (int .Values.service.port)) | quote }} }
- { name: bhe_default_admin_principal_name, value: {{ .Values.admin.user | quote }} }
- { name: bhe_default_admin_email_address, value: {{ .Values.admin.email | quote }} }
- name: bhe_default_admin_password
  valueFrom:
    secretKeyRef: { name: {{ include "bloodhound.secretName" . }}, key: admin-password }
# the password is generated, so the first sign-in does not force a change (upstream's default expires it)
- { name: bhe_default_admin_expire_now, value: {{ .Values.admin.expireNow | quote }} }
{{- if $tls }}
- { name: bhe_tls_cert_file, value: /tls/tls.crt }
- { name: bhe_tls_key_file, value: /tls/tls.key }
{{- end }}
{{- range $k, $v := .Values.settings }}
- { name: {{ $k }}, value: {{ $v | quote }} }
{{- end }}
{{- end -}}
