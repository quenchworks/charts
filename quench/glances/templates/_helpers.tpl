{{/* The web UI and the REST API on 61208. */}}
{{- define "glances.ports" -}}
{{- toJson (list (dict "name" "http" "port" 61208 "servicePort" (int .Values.service.port) "protocol" "TCP")) -}}
{{- end -}}
