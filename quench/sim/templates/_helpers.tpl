{{/* Every port the app listens on, as {name, port, servicePort, protocol}: container, Service and NetworkPolicy. */}}
{{- define "sim.ports" -}}
{{- toJson (list (dict "name" "http" "port" 3000 "servicePort" (int .Values.service.port) "protocol" "TCP")) -}}
{{- end -}}

{{- define "sim.secretName" -}}
{{- .Values.secret.existingSecret | default (include "quench-common.fullname" .) -}}
{{- end -}}

{{/* A sibling image (realtime, migrations) pinned by digest, under image.registry like the main image. */}}
{{- define "sim.siblingImage" -}}
{{- $i := .image -}}
{{- $ref := printf "%s@%s" (required "image repository is required" $i.repository) (required "image digest is required (pinned by digest, never a tag)" $i.digest) -}}
{{- with .ctx.Values.image.registry }}{{ $ref = printf "%s/%s" (trimSuffix "/" .) $ref }}{{ end -}}
{{- $ref -}}
{{- end -}}

{{- define "sim.realtimeSelector" -}}
app.kubernetes.io/name: sim-realtime
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end -}}

{{/* DATABASE_URL. The bundled PostgreSQL password comes from the postgresql subchart's own Secret and is spliced in by
     Kubernetes $(VAR) expansion; generated passwords are alphanumeric, so they are URL-safe. */}}
{{- define "sim.dbEnv" -}}
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
{{- end -}}

{{- define "sim.secretEnv" -}}
{{- range $k := list "BETTER_AUTH_SECRET" "ENCRYPTION_KEY" "INTERNAL_API_SECRET" "CRON_SECRET" }}
- name: {{ $k }}
  valueFrom:
    secretKeyRef: { name: {{ include "sim.secretName" $ }}, key: {{ $k | lower | replace "_" "-" }} }
{{- end }}
{{- end -}}

{{/* Settings shared by the app and realtime pods. */}}
{{- define "sim.env" -}}
{{- if not .Values.baseUrl }}{{ fail "set baseUrl: the public URL users open, e.g. https://sim.example.com" }}{{ end }}
{{- $url := .Values.baseUrl | trimSuffix "/" }}
- { name: NEXT_PUBLIC_APP_URL, value: {{ $url | quote }} }
- { name: BETTER_AUTH_URL, value: {{ $url | quote }} }
{{- include "sim.dbEnv" . }}
{{- include "sim.secretEnv" . }}
{{- range $k, $v := .Values.settings }}
- { name: {{ $k }}, value: {{ $v | quote }} }
{{- end }}
{{- end -}}
