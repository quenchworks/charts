{{/* Every port 3proxy listens on, as {name, port, protocol}: container, Service and NetworkPolicy. */}}
{{- define "3proxy.ports" -}}
{{- $p := list -}}
{{- if .Values.http.enabled }}{{ $p = append $p (dict "name" "http" "port" (int .Values.http.port) "protocol" "TCP") }}{{ end -}}
{{- if .Values.socks.enabled }}{{ $p = append $p (dict "name" "socks" "port" (int .Values.socks.port) "protocol" "TCP") }}{{ end -}}
{{- range .Values.extraPorts }}{{ $p = append $p (dict "name" .name "port" (int .port) "protocol" (default "TCP" .protocol)) }}{{ end -}}
{{- toJson $p -}}
{{- end -}}

{{/* The default user's password: the value, else the one already in the Secret, else a new
     random one. Resolved once and stored back into .Values so every include agrees. */}}
{{- define "3proxy.password" -}}
{{- if not .Values.auth.password -}}
{{- $s := lookup "v1" "Secret" .Release.Namespace (include "quench-common.fullname" .) -}}
{{- $pw := randAlphaNum 24 -}}
{{- if and $s $s.data (index $s.data "password") -}}{{- $pw = index $s.data "password" | b64dec -}}{{- end -}}
{{- $_ := set .Values.auth "password" $pw -}}
{{- end -}}
{{ .Values.auth.password }}
{{- end -}}

{{- define "3proxy.config" -}}
nscache 65536
log
users {{ .Values.auth.username }}:CL:{{ include "3proxy.password" . }}
{{- range .Values.auth.extraUsers }}
users {{ .name }}:CL:{{ .password }}
{{- end }}
auth strong
deny * * 127.0.0.0/8
allow *
{{- if .Values.http.enabled }}
proxy -p{{ .Values.http.port }}
{{- end }}
{{- if .Values.socks.enabled }}
socks -p{{ .Values.socks.port }}
{{- end }}
{{- with .Values.extraConfig }}
{{ . }}
{{- end }}
{{- end -}}
