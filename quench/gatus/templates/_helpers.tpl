{{/* Every port Gatus listens on, as {name, port, servicePort, protocol}: container, Service and NetworkPolicy. */}}
{{- define "gatus.ports" -}}
{{- toJson (list (dict "name" "http" "port" 8080 "servicePort" (int .Values.service.port) "protocol" "TCP")) -}}
{{- end -}}

{{- define "gatus.pvcName" -}}
{{- .Values.persistence.existingClaim | default (include "quench-common.fullname" .) -}}
{{- end -}}

{{/* config.yaml: the user's config, with SQLite storage on the volume when persistence is on. */}}
{{- define "gatus.config" -}}
{{- $c := deepCopy .Values.config -}}
{{- if .Values.persistence.enabled }}{{ $_ := set $c "storage" (dict "type" "sqlite" "path" "/data/data.db") }}{{ end -}}
{{- toYaml $c -}}
{{- end -}}
