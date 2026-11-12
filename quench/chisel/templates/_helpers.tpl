{{/* Every port chisel listens on, as {name, port, protocol}: container, Service and NetworkPolicy. */}}
{{- define "chisel.ports" -}}
{{- $p := list (dict "name" "tunnel" "port" (int .Values.port) "protocol" "TCP") -}}
{{- range .Values.extraPorts }}{{ $p = append $p (dict "name" .name "port" (int .port) "protocol" (default "TCP" .protocol)) }}{{ end -}}
{{- toJson $p -}}
{{- end -}}
