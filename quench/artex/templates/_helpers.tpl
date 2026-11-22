{{/* Every port the server listens on, as {name, port, servicePort, protocol}: container, Service and NetworkPolicy. */}}
{{- define "artex.ports" -}}
{{- toJson (list (dict "name" "http" "port" 8787 "servicePort" (int .Values.service.port) "protocol" "TCP")) -}}
{{- end -}}

{{/* ARTEX settings. ARTEX_PG_DSN is composed from ARTEX_DB_PASSWORD with Kubernetes $(VAR) expansion, so the
     password stays in a Secret: the bundled PostgreSQL (its password under postgres-password) or externalDatabase. */}}
{{- define "artex.env" -}}
{{- if .Values.postgresql.enabled }}
- name: ARTEX_DB_PASSWORD
  valueFrom:
    secretKeyRef: { name: {{ printf "%s-postgresql" .Release.Name }}, key: postgres-password }
- name: ARTEX_PG_DSN
  value: {{ printf "postgres://%s:$(ARTEX_DB_PASSWORD)@%s-postgresql:5432/%s?sslmode=disable" .Values.postgresql.auth.username .Release.Name .Values.postgresql.auth.database | quote }}
{{- else }}
- name: ARTEX_DB_PASSWORD
  valueFrom:
    secretKeyRef: { name: {{ required "externalDatabase.existingSecret is required when postgresql.enabled=false" .Values.externalDatabase.existingSecret }}, key: {{ .Values.externalDatabase.existingSecretPasswordKey }} }
- name: ARTEX_PG_DSN
  value: {{ printf "postgres://%s:$(ARTEX_DB_PASSWORD)@%s:%v/%s?sslmode=%s" .Values.externalDatabase.username (required "externalDatabase.host is required when postgresql.enabled=false" .Values.externalDatabase.host) .Values.externalDatabase.port .Values.externalDatabase.database .Values.externalDatabase.sslmode | quote }}
{{- end }}
{{- range $k, $v := .Values.settings }}
- { name: {{ $k }}, value: {{ $v | quote }} }
{{- end }}
{{- end -}}
