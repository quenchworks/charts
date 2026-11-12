{{/* Every port Promxy listens on, as {name, port, servicePort, protocol}: container, Service and NetworkPolicy. */}}
{{- define "promxy.ports" -}}
{{- toJson (list (dict "name" "http" "port" 8082 "servicePort" (int .Values.service.port) "protocol" "TCP")) -}}
{{- end -}}

{{/* promxy.yaml: the user's config as given. */}}
{{- define "promxy.config" -}}
{{- toYaml .Values.config -}}
{{- end -}}
