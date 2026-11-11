{{/* Every port GOST listens on, as {name, port, protocol}: container, Service and NetworkPolicy. */}}
{{- define "gost.ports" -}}
{{- $p := list (dict "name" "metrics" "port" (int .Values.metrics.port) "protocol" "TCP") -}}
{{- if .Values.proxy.enabled }}{{ $p = append $p (dict "name" "proxy" "port" (int .Values.proxy.port) "protocol" "TCP") }}{{ end -}}
{{- range .Values.extraPorts }}{{ $p = append $p (dict "name" .name "port" (int .port) "protocol" (default "TCP" .protocol)) }}{{ end -}}
{{- toJson $p -}}
{{- end -}}
