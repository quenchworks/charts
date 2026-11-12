{{/* Every port linkding listens on, as {name, port, servicePort, protocol}: container, Service and NetworkPolicy. */}}
{{- define "linkding.ports" -}}
{{- toJson (list (dict "name" "http" "port" 9090 "servicePort" (int .Values.service.port) "protocol" "TCP")) -}}
{{- end -}}

{{- define "linkding.pvcName" -}}
{{- .Values.persistence.existingClaim | default (include "quench-common.fullname" .) -}}
{{- end -}}

{{- define "linkding.secretName" -}}
{{- .Values.superuser.existingSecret | default (printf "%s-superuser" (include "quench-common.fullname" .)) -}}
{{- end -}}
