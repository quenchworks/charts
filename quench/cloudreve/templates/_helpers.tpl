{{/* Every port Cloudreve listens on, as {name, port, servicePort, protocol}: container, Service and NetworkPolicy. */}}
{{- define "cloudreve.ports" -}}
{{- toJson (list (dict "name" "http" "port" 5212 "servicePort" (int .Values.service.port) "protocol" "TCP")) -}}
{{- end -}}

{{- define "cloudreve.pvcName" -}}
{{- .Values.persistence.existingClaim | default (include "quench-common.fullname" .) -}}
{{- end -}}

{{- define "cloudreve.secretName" -}}
{{- .Values.admin.existingSecret | default (include "quench-common.fullname" .) -}}
{{- end -}}
