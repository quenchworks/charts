{{/* Every port GLAuth listens on, as {name, port, servicePort, protocol}: container, Service and NetworkPolicy. */}}
{{- define "glauth.ports" -}}
{{- toJson (list (dict "name" "ldap" "port" 3893 "servicePort" (int .Values.service.port) "protocol" "TCP")) -}}
{{- end -}}

{{- define "glauth.secretName" -}}
{{- printf "%s-config" (include "quench-common.fullname" .) -}}
{{- end -}}
