{{/* The one port changedetection.io listens on (HTTPS when tls.enabled), as {name, port, protocol}. */}}
{{- define "changedetection.ports" -}}
{{- toJson (list (dict "name" "http" "port" 5000 "protocol" "TCP")) -}}
{{- end -}}

{{- define "changedetection.pvcName" -}}
{{- .Values.persistence.existingClaim | default (include "quench-common.fullname" .) -}}
{{- end -}}
