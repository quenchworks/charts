{{/* Every port tusd listens on, as {name, port, servicePort, protocol}: container, Service and NetworkPolicy. */}}
{{- define "tusd.ports" -}}
{{- toJson (list (dict "name" "http" "port" 8080 "servicePort" (int .Values.service.port) "protocol" "TCP")) -}}
{{- end -}}

{{- define "tusd.pvcName" -}}
{{- .Values.persistence.existingClaim | default (include "quench-common.fullname" .) -}}
{{- end -}}
