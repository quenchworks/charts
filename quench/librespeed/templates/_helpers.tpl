{{/* The web UI and the test endpoints on 8989. */}}
{{- define "librespeed.ports" -}}
{{- toJson (list (dict "name" "http" "port" 8989 "servicePort" (int .Values.service.port) "protocol" "TCP")) -}}
{{- end -}}

{{- define "librespeed.settings" -}}
{{- $v := .ctx.Values -}}
bind_address=""
listen_port=8989
proxyprotocol_port=0
server_lat={{ $v.server.latitude }}
server_lng={{ $v.server.longitude }}
ipinfo_api_key={{ $v.ipinfoApiKey | quote }}
assets_path=""
statistics_password={{ ternary .pw "PASSWORD" $v.telemetry.enabled | quote }}
redact_ip_addresses={{ $v.telemetry.redactIpAddresses }}
database_type={{ ternary "sqlite" "none" $v.telemetry.enabled | quote }}
database_file="/data/speedtest.db"
enable_tls=false
enable_http2=false
{{- end -}}
