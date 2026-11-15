{{/* Every port gonic listens on, as {name, port, servicePort, protocol}: container, Service and NetworkPolicy. */}}
{{- define "gonic.ports" -}}
{{- toJson (list (dict "name" "http" "port" 4747 "servicePort" (int .Values.service.port) "protocol" "TCP")) -}}
{{- end -}}

{{- define "gonic.pvcName" -}}
{{- .Values.persistence.existingClaim | default (include "quench-common.fullname" .) -}}
{{- end -}}

{{- define "gonic.secretName" -}}
{{- .Values.admin.existingSecret | default (include "quench-common.fullname" .) -}}
{{- end -}}
