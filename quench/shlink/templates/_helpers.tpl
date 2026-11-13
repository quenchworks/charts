{{/* Every port the pod listens on, as {name, port, protocol}: container and NetworkPolicy.
     https is the TLS sidecar, only with tls.enabled. */}}
{{- define "shlink.ports" -}}
{{- $p := list (dict "name" "http" "port" 8080 "protocol" "TCP") -}}
{{- if include "quench-common.tls.enabled" . }}{{ $p = append $p (dict "name" "https" "port" 8443 "protocol" "TCP") }}{{ end -}}
{{- toJson $p -}}
{{- end -}}

{{- define "shlink.pvcName" -}}
{{- .Values.persistence.existingClaim | default (include "quench-common.fullname" .) -}}
{{- end -}}

{{- define "shlink.apiKeySecret" -}}
{{- .Values.apiKey.existingSecret | default (printf "%s-api-key" (include "quench-common.fullname" .)) -}}
{{- end -}}
