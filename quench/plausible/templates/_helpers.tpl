{{- define "plausible.secretName" -}}
{{- .Values.secret.existingSecret | default (include "quench-common.fullname" .) -}}
{{- end -}}

{{- define "plausible.baseUrl" -}}
{{- printf "%s://%s" .Values.publicScheme (required "domain is required (the public host of Plausible)" .Values.domain) -}}
{{- end -}}

{{/* Env shared by the migrations and the server: secrets, BASE_URL and both database URLs. The URLs embed
     $(PG_PASSWORD) and $(CH_PASSWORD) from the env before them. */}}
{{- define "plausible.env" -}}
{{- /* The BEAM sizes its port table from the open-file limit; containerd sets that near 1e9 (kind and many clusters),
       and the VM then OOMs at start. 65536 ports is far more than Plausible opens. */}}
- { name: ERL_MAX_PORTS, value: "65536" }
- name: SECRET_KEY_BASE
  valueFrom:
    secretKeyRef: { name: {{ include "plausible.secretName" . }}, key: secret-key-base }
- { name: BASE_URL, value: {{ include "plausible.baseUrl" . | quote }} }
{{- if .Values.postgresql.enabled }}
- name: PG_PASSWORD
  valueFrom:
    secretKeyRef: { name: {{ printf "%s-postgresql" .Release.Name }}, key: postgres-password }
- { name: DATABASE_URL, value: "postgres://{{ .Values.postgresql.auth.username }}:$(PG_PASSWORD)@{{ .Release.Name }}-postgresql:5432/{{ .Values.postgresql.auth.database }}" }
{{- else }}
- name: DATABASE_URL
  valueFrom:
    secretKeyRef: { name: {{ required "externalDatabase.existingSecret" .Values.externalDatabase.existingSecret }}, key: database-url }
{{- end }}
{{- if .Values.clickhouse.enabled }}
- name: CH_PASSWORD
  valueFrom:
    secretKeyRef: { name: {{ printf "%s-clickhouse" .Release.Name }}, key: admin-password }
- { name: CLICKHOUSE_DATABASE_URL, value: "http://{{ .Values.clickhouse.auth.username }}:$(CH_PASSWORD)@{{ .Release.Name }}-clickhouse:8123/plausible_events_db" }
{{- else }}
- name: CLICKHOUSE_DATABASE_URL
  valueFrom:
    secretKeyRef: { name: {{ required "externalDatabase.existingSecret" .Values.externalDatabase.existingSecret }}, key: clickhouse-database-url }
{{- end }}
{{- with .Values.disableRegistration }}
- { name: DISABLE_REGISTRATION, value: {{ . | quote }} }
{{- end }}
{{- range $k, $v := .Values.env }}
- { name: {{ $k }}, value: {{ $v | quote }} }
{{- end }}
{{- end -}}

{{- define "plausible.ports" -}}
{{- toJson (list (dict "port" "http" "protocol" "TCP")) -}}
{{- end -}}
