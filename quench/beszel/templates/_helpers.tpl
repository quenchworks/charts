{{/* Every port the hub listens on, as {name, port, servicePort, protocol}: container, Service and NetworkPolicy. */}}
{{- define "beszel.ports" -}}
{{- toJson (list (dict "name" "http" "port" 8090 "servicePort" (int .Values.service.port) "protocol" "TCP")) -}}
{{- end -}}

{{- define "beszel.pvcName" -}}
{{- .Values.persistence.existingClaim | default (include "quench-common.fullname" .) -}}
{{- end -}}

{{- define "beszel.secretName" -}}
{{- .Values.admin.existingSecret | default (printf "%s-admin" (include "quench-common.fullname" .)) -}}
{{- end -}}
