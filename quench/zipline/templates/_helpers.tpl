{{/* Every port the server listens on, as {name, port, servicePort, protocol}: container, Service and NetworkPolicy. */}}
{{- define "zipline.ports" -}}
{{- toJson (list (dict "name" "http" "port" 3000 "servicePort" (int .Values.service.port) "protocol" "TCP")) -}}
{{- end -}}

{{- define "zipline.pvcName" -}}
{{- .Values.persistence.existingClaim | default (include "quench-common.fullname" .) -}}
{{- end -}}

{{- define "zipline.secretName" -}}
{{- .Values.auth.existingSecret | default (include "quench-common.fullname" .) -}}
{{- end -}}

{{/* Zipline settings. The bundled PostgreSQL password comes from the postgresql subchart's own Secret and is spliced
     into DATABASE_URL by Kubernetes $(VAR) expansion; generated passwords are alphanumeric, so they are URL-safe. */}}
{{- define "zipline.env" -}}
- name: CORE_SECRET
  valueFrom:
    secretKeyRef: { name: {{ include "zipline.secretName" . }}, key: core-secret }
{{- if .Values.postgresql.enabled }}
- name: DB_PASSWORD
  valueFrom:
    secretKeyRef: { name: {{ printf "%s-postgresql" .Release.Name }}, key: postgres-password }
- { name: DATABASE_URL, value: "postgresql://{{ .Values.postgresql.auth.username }}:$(DB_PASSWORD)@{{ .Release.Name }}-postgresql:5432/{{ .Values.postgresql.auth.database }}" }
{{- else if .Values.externalDatabase.existingSecret }}
- name: DATABASE_URL
  valueFrom:
    secretKeyRef: { name: {{ .Values.externalDatabase.existingSecret }}, key: {{ .Values.externalDatabase.existingSecretKey }} }
{{- else }}
{{- fail "set postgresql.enabled, or externalDatabase.existingSecret with a DATABASE_URL" }}
{{- end }}
{{- range $k, $v := .Values.settings }}
- { name: {{ $k }}, value: {{ $v | quote }} }
{{- end }}
{{- end -}}
