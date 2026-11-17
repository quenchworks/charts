{{/* Every port the server listens on, as {name, port, servicePort, protocol}: container, Service and NetworkPolicy. */}}
{{- define "wikijs.ports" -}}
{{- toJson (list (dict "name" "http" "port" 3000 "servicePort" (int .Values.service.port) "protocol" "TCP")) -}}
{{- end -}}

{{- define "wikijs.pvcName" -}}
{{- .Values.persistence.existingClaim | default (include "quench-common.fullname" .) -}}
{{- end -}}

{{- define "wikijs.secretName" -}}
{{- .Values.auth.existingSecret | default (include "quench-common.fullname" .) -}}
{{- end -}}

{{/* Wiki.js settings. config.yml in the image reads DB_* from the environment. The first administrator comes from
     ADMIN_EMAIL / ADMIN_PASS on the first start (upstream would otherwise create admin@example.com / 12345678). */}}
{{- define "wikijs.env" -}}
- { name: ADMIN_EMAIL, value: {{ .Values.auth.email | quote }} }
- name: ADMIN_PASS
  valueFrom:
    secretKeyRef: { name: {{ include "wikijs.secretName" . }}, key: password }
{{- if .Values.postgresql.enabled }}
- { name: DB_HOST, value: {{ printf "%s-postgresql" .Release.Name | quote }} }
- { name: DB_PORT, value: "5432" }
- { name: DB_USER, value: {{ .Values.postgresql.auth.username | quote }} }
- { name: DB_NAME, value: {{ .Values.postgresql.auth.database | quote }} }
- name: DB_PASS
  valueFrom:
    secretKeyRef: { name: {{ printf "%s-postgresql" .Release.Name }}, key: postgres-password }
{{- else if .Values.externalDatabase.host }}
- { name: DB_HOST, value: {{ .Values.externalDatabase.host | quote }} }
- { name: DB_PORT, value: {{ .Values.externalDatabase.port | quote }} }
- { name: DB_USER, value: {{ .Values.externalDatabase.user | quote }} }
- { name: DB_NAME, value: {{ .Values.externalDatabase.database | quote }} }
- { name: DB_SSL, value: {{ .Values.externalDatabase.ssl | quote }} }
- name: DB_PASS
  valueFrom:
    secretKeyRef: { name: {{ required "externalDatabase.existingSecret" .Values.externalDatabase.existingSecret }}, key: {{ .Values.externalDatabase.existingSecretKey }} }
{{- else }}
{{- fail "set postgresql.enabled, or externalDatabase.host with externalDatabase.existingSecret" }}
{{- end }}
{{- range $k, $v := .Values.settings }}
- { name: {{ $k }}, value: {{ $v | quote }} }
{{- end }}
{{- end -}}
