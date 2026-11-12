{{/* Every port sish listens on, as {name, port, protocol}: container, Service and NetworkPolicy. */}}
{{- define "sish.ports" -}}
{{- toJson (list (dict "name" "ssh" "port" 2222 "protocol" "TCP") (dict "name" "http" "port" 8080 "protocol" "TCP")) -}}
{{- end -}}
