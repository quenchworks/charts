{{- define "hoppscotch.image" -}}
{{- printf "%s@%s" .repository .digest -}}
{{- end -}}

{{- define "hoppscotch.secretName" -}}
{{- .Values.secret.existingSecret | default (include "quench-common.fullname" .) -}}
{{- end -}}

{{/* <fullname>-<component> */}}
{{- define "hoppscotch.name" -}}
{{- printf "%s-%s" (include "quench-common.fullname" .ctx) .component | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "hoppscotch.selectorLabels" -}}
{{ include "quench-common.selectorLabels" .ctx }}
app.kubernetes.io/component: {{ .component }}
{{- end -}}

{{- define "hoppscotch.webUrl" -}}
{{- printf "%s://%s" .Values.publicScheme (required "domain is required (the public host of the web app and the backend)" .Values.domain) -}}
{{- end -}}

{{- define "hoppscotch.adminUrl" -}}
{{- printf "%s://%s" .Values.publicScheme (required "adminDomain is required (the public host of the admin dashboard)" .Values.adminDomain) -}}
{{- end -}}

{{/* The VITE_* settings the backend, the web app and the admin dashboard share. */}}
{{- define "hoppscotch.viteEnv" -}}
{{- $web := include "hoppscotch.webUrl" . -}}
{{- $ws := printf "%s://%s/graphql" (ternary "wss" "ws" (eq .Values.publicScheme "https")) .Values.domain -}}
- { name: VITE_BASE_URL, value: {{ $web | quote }} }
- { name: VITE_SHORTCODE_BASE_URL, value: {{ $web | quote }} }
- { name: VITE_ADMIN_URL, value: {{ include "hoppscotch.adminUrl" . | quote }} }
- { name: VITE_BACKEND_GQL_URL, value: {{ printf "%s/graphql" $web | quote }} }
- { name: VITE_BACKEND_WS_URL, value: {{ $ws | quote }} }
- { name: VITE_BACKEND_API_URL, value: {{ printf "%s/v1" $web | quote }} }
{{- range $k, $v := .Values.viteEnv }}
- { name: {{ $k }}, value: {{ $v | quote }} }
{{- end }}
{{- end -}}

{{/* DATABASE_URL for the backend and its migrations, with $(DB_PASSWORD) from the env before it. */}}
{{- define "hoppscotch.dbEnv" -}}
- name: DB_PASSWORD
  valueFrom:
    secretKeyRef:
      {{- if .Values.postgresql.enabled }}
      name: {{ printf "%s-postgresql" .Release.Name }}
      key: postgres-password
      {{- else }}
      name: {{ required "externalDatabase.existingSecret" .Values.externalDatabase.existingSecret }}
      key: {{ .Values.externalDatabase.existingSecretKey }}
      {{- end }}
{{- if .Values.postgresql.enabled }}
- { name: DATABASE_URL, value: "postgresql://{{ .Values.postgresql.auth.username }}:$(DB_PASSWORD)@{{ .Release.Name }}-postgresql:5432/{{ .Values.postgresql.auth.database }}" }
{{- else }}
- { name: DATABASE_URL, value: "postgresql://{{ .Values.externalDatabase.username }}:$(DB_PASSWORD)@{{ required "externalDatabase.host" .Values.externalDatabase.host }}:{{ .Values.externalDatabase.port }}/{{ .Values.externalDatabase.database }}?sslmode={{ .Values.externalDatabase.sslmode }}" }
{{- end }}
{{- end -}}

{{- define "hoppscotch.ports" -}}
{{- toJson (list
  (dict "port" "http" "protocol" "TCP")
  (dict "port" "web" "protocol" "TCP")
  (dict "port" "desktop" "protocol" "TCP")
  (dict "port" "admin" "protocol" "TCP")) -}}
{{- end -}}
