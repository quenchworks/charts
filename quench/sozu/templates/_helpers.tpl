{{/* Every port Sozu listens on, as {name, port, protocol}: container, Service and NetworkPolicy. */}}
{{- define "sozu.ports" -}}
{{- $p := list (dict "name" "http" "port" (int .Values.listeners.http.port) "protocol" "TCP") -}}
{{- if .Values.listeners.https.enabled }}{{ $p = append $p (dict "name" "https" "port" (int .Values.listeners.https.port) "protocol" "TCP") }}{{ end -}}
{{- toJson $p -}}
{{- end -}}

{{- define "sozu.config" -}}
saved_state = "/var/lib/sozu/state.json"
log_level = {{ .Values.logLevel | quote }}
log_target = "stdout"
command_socket = "/run/sozu/sozu.sock"
pid_file_path = "/run/sozu/sozu.pid"
worker_count = {{ .Values.workerCount }}
worker_automatic_restart = true
activate_listeners = true
{{- with .Values.extraGlobalConfig }}
{{ . }}
{{- end }}

[[listeners]]
protocol = "http"
address = "0.0.0.0:{{ .Values.listeners.http.port }}"
{{- if .Values.listeners.https.enabled }}

[[listeners]]
protocol = "https"
address = "0.0.0.0:{{ .Values.listeners.https.port }}"
tls_versions = ["TLS_V12", "TLS_V13"]
{{- end }}
{{- with .Values.clusters }}

[clusters]
{{ . }}
{{- end }}
{{- end -}}
