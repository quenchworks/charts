{{/* Every port Seerr listens on, as {name, port, servicePort, protocol}: container, Service and NetworkPolicy. */}}
{{- define "seerr.ports" -}}
{{- toJson (list (dict "name" "http" "port" 5055 "servicePort" (int .Values.service.port) "protocol" "TCP")) -}}
{{- end -}}

{{- define "seerr.pvcName" -}}
{{- .Values.persistence.existingClaim | default (include "quench-common.fullname" .) -}}
{{- end -}}
