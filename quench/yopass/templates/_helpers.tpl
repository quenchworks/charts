{{/* Every port the server listens on, as {name, port, servicePort, protocol}: container, Service and NetworkPolicy. */}}
{{- define "yopass.ports" -}}
{{- toJson (list (dict "name" (ternary "https" "http" (eq (include "quench-common.tls.enabled" .) "true")) "port" 1337 "servicePort" (int .Values.service.port) "protocol" "TCP")) -}}
{{- end -}}

{{/* yopass-server settings: every flag reads an environment variable of the same name. */}}
{{- define "yopass.env" -}}
{{- if eq .Values.store.type "memcached" }}
- { name: DATABASE, value: memcached }
{{- if .Values.store.memcached }}
- { name: MEMCACHED, value: {{ .Values.store.memcached | quote }} }
{{- else if .Values.memcached.enabled }}
- { name: MEMCACHED, value: "{{ .Release.Name }}-memcached:11211" }
{{- else }}
{{- fail "store.type memcached needs memcached.enabled or store.memcached (host:port)" }}
{{- end }}
{{- else if eq .Values.store.type "redis" }}
- { name: DATABASE, value: redis }
{{- if .Values.store.redisURL }}
- { name: REDIS, value: {{ .Values.store.redisURL | quote }} }
{{- else if not .Values.extraEnvVarsSecret }}
{{- fail "store.type redis needs store.redisURL, or extraEnvVarsSecret with a REDIS key" }}
{{- end }}
{{- else }}
{{- fail "store.type must be memcached or redis" }}
{{- end }}
{{- if include "quench-common.tls.enabled" . }}
- { name: TLS_CERT, value: /tls/tls.crt }
- { name: TLS_KEY, value: /tls/tls.key }
{{- end }}
{{- range $k, $v := .Values.settings }}
- { name: {{ $k }}, value: {{ $v | quote }} }
{{- end }}
{{- end -}}
