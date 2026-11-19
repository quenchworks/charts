{{/* Every port Kutt listens on, as {name, port, servicePort, protocol}: container, Service and NetworkPolicy. */}}
{{- define "kutt.ports" -}}
{{- toJson (list (dict "name" "http" "port" 3000 "servicePort" (int .Values.service.port) "protocol" "TCP")) -}}
{{- end -}}

{{- define "kutt.pvcName" -}}
{{- .Values.persistence.existingClaim | default (include "quench-common.fullname" .) -}}
{{- end -}}

{{- define "kutt.secretName" -}}
{{- .Values.existingSecret | default (include "quench-common.fullname" .) -}}
{{- end -}}
