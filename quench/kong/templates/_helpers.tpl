{{/* ServiceAccount name for the kong pod. */}}
{{- define "kong.serviceAccountName" -}}
{{- if .Values.serviceAccount.create -}}
{{- default (include "quench-common.fullname" .) .Values.serviceAccount.name -}}
{{- else -}}
{{- default "default" .Values.serviceAccount.name -}}
{{- end -}}
{{- end -}}

{{/* ConfigMap holding the declarative config (DB-less mode only). */}}
{{- define "kong.configMapName" -}}
{{- printf "%s-declarative" (include "quench-common.fullname" .) -}}
{{- end -}}

{{/* Secret holding the Postgres password (database mode, when not using an existing one). */}}
{{- define "kong.secretName" -}}
{{- printf "%s-pg" (include "quench-common.fullname" .) -}}
{{- end -}}

{{/* True when running with a real database rather than DB-less. */}}
{{- define "kong.dbMode" -}}
{{- if ne (toString .Values.database) "off" -}}true{{- end -}}
{{- end -}}

{{/*
Postgres environment, shared by the Deployment and the migration Jobs. Defined once on
purpose: if the Job connected with different settings than the pod (a missing CA, a
different sslmode) migrations would pass and the gateway would still fail to start.
*/}}
{{- define "kong.dbEnv" -}}
- name: KONG_PREFIX
  value: /kong_prefix
- name: KONG_DATABASE
  value: {{ .Values.database | quote }}
- name: KONG_PG_HOST
  value: {{ required "postgres.host is required when database is not off" .Values.postgres.host | quote }}
- name: KONG_PG_PORT
  value: {{ .Values.postgres.port | quote }}
- name: KONG_PG_DATABASE
  value: {{ .Values.postgres.database | quote }}
- name: KONG_PG_USER
  value: {{ .Values.postgres.user | quote }}
- name: KONG_PG_SSL
  value: {{ .Values.postgres.ssl | quote }}
- name: KONG_PG_SSL_VERIFY
  value: {{ .Values.postgres.sslVerify | quote }}
{{- with .Values.postgres.luaSslTrustedCertificate }}
- name: KONG_LUA_SSL_TRUSTED_CERTIFICATE
  value: {{ . | quote }}
{{- end }}
{{- if or .Values.postgres.existingSecret .Values.postgres.password }}
- name: KONG_PG_PASSWORD
  valueFrom:
    secretKeyRef:
      name: {{ .Values.postgres.existingSecret | default (include "kong.secretName" .) }}
      key: {{ .Values.postgres.existingSecretPasswordKey }}
{{- end }}
{{- end -}}
