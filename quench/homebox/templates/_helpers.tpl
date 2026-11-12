{{/* Every port the pod listens on, as {name, port, protocol}: container and NetworkPolicy.
     https is the TLS sidecar, only with tls.enabled. */}}
{{- define "homebox.ports" -}}
{{- $p := list (dict "name" "http" "port" 7745 "protocol" "TCP") -}}
{{- if include "quench-common.tls.enabled" . }}{{ $p = append $p (dict "name" "https" "port" 8443 "protocol" "TCP") }}{{ end -}}
{{- toJson $p -}}
{{- end -}}

{{- define "homebox.pvcName" -}}
{{- .Values.persistence.existingClaim | default (include "quench-common.fullname" .) -}}
{{- end -}}

{{- define "homebox.secretName" -}}
{{- .Values.apiKeyPepper.existingSecret | default (include "quench-common.fullname" .) -}}
{{- end -}}
