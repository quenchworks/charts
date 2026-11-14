{{/* Every port Memos listens on, as {name, port, servicePort, protocol}: container, Service and NetworkPolicy. */}}
{{- define "memos.ports" -}}
{{- toJson (list (dict "name" "http" "port" 5230 "servicePort" (int .Values.service.port) "protocol" "TCP")) -}}
{{- end -}}

{{- define "memos.pvcName" -}}
{{- .Values.persistence.existingClaim | default (include "quench-common.fullname" .) -}}
{{- end -}}

{{- define "memos.secretName" -}}
{{- .Values.admin.existingSecret | default (printf "%s-admin" (include "quench-common.fullname" .)) -}}
{{- end -}}
