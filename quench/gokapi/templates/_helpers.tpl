{{/* Every port Gokapi listens on, as {name, port, servicePort, protocol}: container, Service and NetworkPolicy. */}}
{{- define "gokapi.ports" -}}
{{- toJson (list (dict "name" "http" "port" 53842 "servicePort" (int .Values.service.port) "protocol" "TCP")) -}}
{{- end -}}

{{- define "gokapi.pvcName" -}}
{{- .Values.persistence.existingClaim | default (include "quench-common.fullname" .) -}}
{{- end -}}

{{- define "gokapi.secretName" -}}
{{- .Values.admin.existingSecret | default (include "quench-common.fullname" .) -}}
{{- end -}}
