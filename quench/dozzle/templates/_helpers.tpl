{{/* Every port Dozzle listens on, as {name, port, servicePort, protocol}: container, Service and NetworkPolicy. */}}
{{- define "dozzle.ports" -}}
{{- toJson (list (dict "name" "http" "port" 8080 "servicePort" (int .Values.service.port) "protocol" "TCP")) -}}
{{- end -}}

{{- define "dozzle.secretName" -}}
{{- printf "%s-auth" (include "quench-common.fullname" .) -}}
{{- end -}}
