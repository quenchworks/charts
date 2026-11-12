{{/* Every port the pod listens on, as {name, port, servicePort, protocol}: container, Service and NetworkPolicy. */}}
{{- define "goaccess.ports" -}}
{{- toJson (list
  (dict "name" "http" "port" 8080 "servicePort" (int .Values.service.port) "protocol" "TCP")
  (dict "name" "ws" "port" 7890 "servicePort" (int .Values.service.wsPort) "protocol" "TCP")) -}}
{{- end -}}
