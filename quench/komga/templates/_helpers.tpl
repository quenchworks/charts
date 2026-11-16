{{/* Every port Komga listens on, as {name, port, servicePort, protocol}: container, Service and NetworkPolicy. */}}
{{- define "komga.ports" -}}
{{- toJson (list (dict "name" (ternary "https" "http" (eq (include "quench-common.tls.enabled" .) "true")) "port" 25600 "servicePort" (int .Values.service.port) "protocol" "TCP")) -}}
{{- end -}}

{{- define "komga.pvcName" -}}
{{- .Values.persistence.existingClaim | default (include "quench-common.fullname" .) -}}
{{- end -}}

{{/* Komga settings. The first account is claimed by the claim Job (templates/claim-job.yaml), not the server. */}}
{{- define "komga.env" -}}
{{- if include "quench-common.tls.enabled" . }}
- { name: SERVER_SSL_ENABLED, value: "true" }
- { name: SERVER_SSL_CERTIFICATE, value: "file:/tls/tls.crt" }
- { name: SERVER_SSL_CERTIFICATEPRIVATEKEY, value: "file:/tls/tls.key" }
{{- end }}
{{- range $k, $v := .Values.settings }}
- { name: {{ $k }}, value: {{ $v | quote }} }
{{- end }}
{{- end -}}
