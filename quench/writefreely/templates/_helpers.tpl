{{/* Every port WriteFreely listens on, as {name, port, servicePort, protocol}: container, Service and NetworkPolicy. */}}
{{- define "writefreely.ports" -}}
{{- toJson (list (dict "name" "http" "port" 8080 "servicePort" (int .Values.service.port) "protocol" "TCP")) -}}
{{- end -}}

{{- define "writefreely.pvcName" -}}
{{- .Values.persistence.existingClaim | default (include "quench-common.fullname" .) -}}
{{- end -}}

{{- define "writefreely.secretName" -}}
{{- .Values.admin.existingSecret | default (include "quench-common.fullname" .) -}}
{{- end -}}

{{/* config.ini: the image's defaults (SQLite and keys on /data, assets in /usr/share/writefreely) plus the site settings. */}}
{{- define "writefreely.config" -}}
[server]
port                 = 8080
bind                 = 0.0.0.0
templates_parent_dir = /usr/share/writefreely
static_parent_dir    = /usr/share/writefreely
pages_parent_dir     = /usr/share/writefreely
keys_parent_dir      = /data

[database]
type     = sqlite3
filename = /data/writefreely.db

[app]
site_name         = {{ .Values.siteName }}
site_description  = {{ .Values.siteDescription }}
host              = {{ required "host is required: the public URL, e.g. https://blog.example.com" .Values.host }}
single_user       = {{ .Values.singleUser }}
open_registration = {{ .Values.openRegistration }}
min_username_len  = 3
max_blogs         = {{ .Values.maxBlogs }}
federation        = {{ .Values.federation }}
public_stats      = true
private           = {{ .Values.private }}
local_timeline    = {{ .Values.localTimeline }}
update_checks     = false
{{- with .Values.extraConfig }}

{{ . }}
{{- end }}
{{- end -}}
