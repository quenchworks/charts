{{/* Every port the server listens on, as {name, port, servicePort, protocol}: container, Service and NetworkPolicy. */}}
{{- define "kener.ports" -}}
{{- toJson (list (dict "name" "http" "port" 3000 "servicePort" (int .Values.service.port) "protocol" "TCP")) -}}
{{- end -}}

{{- define "kener.secretName" -}}
{{- .Values.secret.existingSecret | default (include "quench-common.fullname" .) -}}
{{- end -}}

{{/* Kener settings. Kener v4 needs Redis: REDIS_URL splices the bundled valkey's password in by Kubernetes $(VAR)
     expansion (generated passwords are alphanumeric, URL-safe). ORIGIN is the public URL SvelteKit checks form posts
     against, so it is required. */}}
{{- define "kener.env" -}}
- name: KENER_SECRET_KEY
  valueFrom:
    secretKeyRef: { name: {{ include "kener.secretName" . }}, key: secret-key }
- { name: ORIGIN, value: {{ required "origin is required: the public URL Kener is served at" .Values.origin | quote }} }
{{- if .Values.valkey.enabled }}
- name: REDIS_PASSWORD
  valueFrom:
    secretKeyRef: { name: {{ printf "%s-valkey" .Release.Name }}, key: valkey-password }
- { name: REDIS_URL, value: "redis://:$(REDIS_PASSWORD)@{{ .Release.Name }}-valkey:6379" }
{{- else if .Values.externalRedis.existingSecret }}
- name: REDIS_URL
  valueFrom:
    secretKeyRef: { name: {{ .Values.externalRedis.existingSecret }}, key: {{ .Values.externalRedis.existingSecretKey }} }
{{- else }}
{{- fail "set valkey.enabled, or externalRedis.existingSecret with a REDIS_URL" }}
{{- end }}
{{- range $k, $v := .Values.settings }}
- { name: {{ $k }}, value: {{ $v | quote }} }
{{- end }}
{{- end -}}
