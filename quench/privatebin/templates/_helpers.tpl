{{/* Every port PrivateBin listens on, as {name, port, servicePort, protocol}: container, Service and NetworkPolicy. */}}
{{- define "privatebin.ports" -}}
{{- toJson (list (dict "name" "http" "port" 8080 "servicePort" (int .Values.service.port) "protocol" "TCP")) -}}
{{- end -}}

{{- define "privatebin.pvcName" -}}
{{- .Values.persistence.existingClaim | default (include "quench-common.fullname" .) -}}
{{- end -}}
