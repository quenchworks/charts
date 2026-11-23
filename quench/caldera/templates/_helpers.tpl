{{/* The web UI, the REST API and the agents' HTTP contact share 8888. */}}
{{- define "caldera.ports" -}}
{{- toJson (list (dict "name" "http" "port" 8888 "servicePort" (int .Values.service.port) "protocol" "TCP")) -}}
{{- end -}}
