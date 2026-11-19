{{/* Every port Dashy listens on, as {name, port, servicePort, protocol}: container, Service and NetworkPolicy. */}}
{{- define "dashy.ports" -}}
{{- $p := list (dict "name" "http" "port" 8080 "servicePort" (int .Values.service.port) "protocol" "TCP") -}}
{{- if .Values.tls.existingSecret }}{{ $p = append $p (dict "name" "https" "port" 8443 "servicePort" (int .Values.service.httpsPort) "protocol" "TCP") }}{{ end -}}
{{- toJson $p -}}
{{- end -}}

{{- define "dashy.pvcName" -}}
{{- .Values.persistence.existingClaim | default (include "quench-common.fullname" .) -}}
{{- end -}}

{{- define "dashy.secretName" -}}
{{- .Values.auth.existingSecret | default (include "quench-common.fullname" .) -}}
{{- end -}}
