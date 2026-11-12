{{/* Every port Trickster listens on, as {name, port, servicePort, protocol}: container, Service and NetworkPolicy. */}}
{{- define "trickster.ports" -}}
{{- toJson (list
  (dict "name" "http" "port" 8480 "servicePort" (int .Values.service.port) "protocol" "TCP")
  (dict "name" "metrics" "port" 8481 "servicePort" 8481 "protocol" "TCP")) -}}
{{- end -}}

{{/* trickster.yaml: the user's config as given (the listener stays on 8480, metrics on 8481). */}}
{{- define "trickster.config" -}}
{{- toYaml .Values.config -}}
{{- end -}}
