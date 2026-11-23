{{/* The API and UI on 8080. */}}
{{- define "kestra.ports" -}}
{{- toJson (list (dict "name" "http" "port" 8080 "servicePort" (int .Values.service.port) "protocol" "TCP")) -}}
{{- end -}}

{{- define "kestra.secretName" -}}
{{- .Values.secret.existingSecret | default (include "quench-common.fullname" .) -}}
{{- end -}}

{{/* Kestra's configuration. Secrets stay out of it: Micronaut resolves ${DB_PASSWORD} and ${BASIC_AUTH_PASSWORD}
     from the environment. Plugin auto-install and the tutorial flows are off: they download unscanned plugin jars
     from Maven at runtime. */}}
{{- define "kestra.config" -}}
{{- $db := .Values.postgresql.enabled -}}
datasources:
  postgres:
    url: {{ ternary (printf "jdbc:postgresql://%s-postgresql:5432/%s" .Release.Name .Values.postgresql.auth.database) (printf "jdbc:postgresql://%s:%d/%s" (.Values.externalDatabase.host | default "unset") (int .Values.externalDatabase.port) .Values.externalDatabase.database) $db | quote }}
    driverClassName: org.postgresql.Driver
    username: {{ ternary .Values.postgresql.auth.username .Values.externalDatabase.username $db | quote }}
    password: ${DB_PASSWORD}
kestra:
  server:
    basic-auth:
      username: {{ .Values.admin.username | quote }}
      password: ${BASIC_AUTH_PASSWORD}
  repository:
    type: postgres
  queue:
    type: postgres
  storage:
    type: local
    local:
      base-path: /app/storage
  tasks:
    tmp-dir:
      path: /tmp/kestra-wd
  plugins:
    auto-install:
      enabled: false
  tutorial-flows:
    enabled: false
  url: {{ .Values.publicUrl | default (printf "http://%s.%s:%d/" (include "quench-common.fullname" .) .Release.Namespace (int .Values.service.port)) | quote }}
{{- end -}}
