{{/* Every port nginx listens on, as {name, port, servicePort, protocol}: container, Service and NetworkPolicy. */}}
{{- define "drawio.ports" -}}
{{- toJson (list (dict "name" (ternary "https" "http" (eq (include "quench-common.tls.enabled" .) "true")) "port" 8080 "servicePort" (int .Values.service.port) "protocol" "TCP")) -}}
{{- end -}}
