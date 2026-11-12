{{/* The one port Actual listens on (HTTPS when tls.enabled), as {name, port, protocol}. */}}
{{- define "actual.ports" -}}
{{- toJson (list (dict "name" "http" "port" 5006 "protocol" "TCP")) -}}
{{- end -}}

{{- define "actual.pvcName" -}}
{{- .Values.persistence.existingClaim | default (include "quench-common.fullname" .) -}}
{{- end -}}
