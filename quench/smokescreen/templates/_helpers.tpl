{{/* Every port Smokescreen listens on, as {name, port, servicePort, protocol}: container, Service and NetworkPolicy. */}}
{{- define "smokescreen.ports" -}}
{{- $p := list (dict "name" "proxy" "port" (int .Values.port) "servicePort" (int .Values.port) "protocol" "TCP") -}}
{{- if .Values.metrics.enabled }}{{ $p = append $p (dict "name" "metrics" "port" 9810 "servicePort" 9810 "protocol" "TCP") }}{{ end -}}
{{- toJson $p -}}
{{- end -}}
