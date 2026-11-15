{{/* Every port Radicale listens on, as {name, port, servicePort, protocol}: container, Service and NetworkPolicy. */}}
{{- define "radicale.ports" -}}
{{- toJson (list (dict "name" (ternary "https" "http" (eq (include "quench-common.tls.enabled" .) "true")) "port" 5232 "servicePort" (int .Values.service.port) "protocol" "TCP")) -}}
{{- end -}}

{{- define "radicale.pvcName" -}}
{{- .Values.persistence.existingClaim | default (include "quench-common.fullname" .) -}}
{{- end -}}

{{- define "radicale.secretName" -}}
{{- .Values.auth.existingSecret | default (include "quench-common.fullname" .) -}}
{{- end -}}

{{/* Radicale's config file (INI). */}}
{{- define "radicale.config" -}}
[server]
hosts = 0.0.0.0:5232
max_content_length = {{ int64 .Values.maxContentLength }}
{{- if include "quench-common.tls.enabled" . }}
ssl = True
certificate = /tls/tls.crt
key = /tls/tls.key
{{- end }}

[auth]
type = htpasswd
htpasswd_filename = /etc/radicale/users
htpasswd_encryption = bcrypt

[rights]
type = {{ .Values.rights }}

[storage]
filesystem_folder = /var/lib/radicale/collections
{{- with .Values.extraConfig }}

{{ . }}
{{- end }}
{{- end -}}
