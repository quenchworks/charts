{{/* Every port Zoraxy listens on, as {name, port, protocol}: container, Service and NetworkPolicy. */}}
{{- define "zoraxy.ports" -}}
{{- $p := list (dict "name" "admin" "port" (int .Values.adminPort) "protocol" "TCP") (dict "name" "proxy" "port" (int .Values.proxyPort) "protocol" "TCP") -}}
{{- range .Values.extraPorts }}{{ $p = append $p (dict "name" .name "port" (int .port) "protocol" (default "TCP" .protocol)) }}{{ end -}}
{{- toJson $p -}}
{{- end -}}

{{- define "zoraxy.claimName" -}}
{{- default (printf "%s-data" (include "quench-common.fullname" .)) .Values.persistence.existingClaim -}}
{{- end -}}
