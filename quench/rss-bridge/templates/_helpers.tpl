{{/* Every port RSS-Bridge listens on, as {name, port, servicePort, protocol}: container, Service and NetworkPolicy. */}}
{{- define "rss-bridge.ports" -}}
{{- toJson (list (dict "name" (ternary "https" "http" (eq (include "quench-common.tls.enabled" .) "true")) "port" 8080 "servicePort" (int .Values.service.port) "protocol" "TCP")) -}}
{{- end -}}


{{/* RSS-Bridge reads RSSBRIDGE_<section>_<key> from the environment. */}}
{{- define "rss-bridge.env" -}}
- { name: RSSBRIDGE_system_enabled_bridges, value: {{ join "," .Values.enabledBridges | quote }} }
{{- if .Values.auth.enabled }}
- { name: RSSBRIDGE_authentication_enable, value: "true" }
- { name: RSSBRIDGE_authentication_username, value: {{ .Values.auth.username | quote }} }
- name: RSSBRIDGE_authentication_password
  valueFrom:
    secretKeyRef: { name: {{ .Values.auth.existingSecret | default (include "quench-common.fullname" .) }}, key: password }
{{- end }}
{{- range $k, $v := .Values.settings }}
- { name: {{ $k }}, value: {{ $v | quote }} }
{{- end }}
{{- end -}}
