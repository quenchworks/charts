{{/* Every port PgDog listens on, as {name, port, protocol}: container, Service and NetworkPolicy. */}}
{{- define "pgdog.ports" -}}
{{- $p := list (dict "name" "postgres" "port" (int .Values.port) "protocol" "TCP") -}}
{{- if .Values.metrics.enabled }}{{ $p = append $p (dict "name" "metrics" "port" (int .Values.metrics.port) "protocol" "TCP") }}{{ end -}}
{{- toJson $p -}}
{{- end -}}

{{/* The admin password: the value, else the one already in the Secret, else a new random one. */}}
{{/* Resolved once and stored back into .Values, so every include in the render agrees. */}}
{{- define "pgdog.adminPassword" -}}
{{- if not .Values.admin.password -}}
{{- $s := lookup "v1" "Secret" .Release.Namespace (include "quench-common.fullname" .) -}}
{{- $pw := randAlphaNum 24 -}}
{{- if and $s $s.data (index $s.data "admin-password") -}}{{- $pw = index $s.data "admin-password" | b64dec -}}{{- end -}}
{{- $_ := set .Values.admin "password" $pw -}}
{{- end -}}
{{ .Values.admin.password }}
{{- end -}}

{{/* A TOML array-of-tables entry from a map: key = value, values as JSON (valid TOML scalars). */}}
{{- define "pgdog.tomlTable" -}}
[[{{ .name }}]]
{{- range $k, $v := .entry }}
{{ $k }} = {{ toJson $v }}
{{- end }}
{{- end -}}

{{- define "pgdog.config" -}}
[general]
host = "0.0.0.0"
port = {{ .Values.port }}
{{- if .Values.metrics.enabled }}
openmetrics_port = {{ .Values.metrics.port }}
openmetrics_host = "0.0.0.0"
{{- end }}
{{- if (include "quench-common.tls.enabled" .) }}
tls_certificate = "/tls/tls.crt"
tls_private_key = "/tls/tls.key"
{{- end }}
{{- range $k, $v := .Values.general }}
{{ $k }} = {{ toJson $v }}
{{- end }}

[admin]
name = "admin"
user = "admin"
password = {{ include "pgdog.adminPassword" . | toJson }}
{{- range .Values.databases }}

{{ include "pgdog.tomlTable" (dict "name" "databases" "entry" .) }}
{{- end }}
{{- with .Values.extraConfig }}

{{ . }}
{{- end }}
{{- end -}}

{{- define "pgdog.users" -}}
{{- range .Values.users }}
{{ include "pgdog.tomlTable" (dict "name" "users" "entry" .) }}
{{ end -}}
{{- end -}}
