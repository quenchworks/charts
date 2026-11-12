{{/* Every port Pushgateway listens on, as {name, port, servicePort, protocol}: container, Service and NetworkPolicy. */}}
{{- define "pushgateway.ports" -}}
{{- toJson (list (dict "name" "http" "port" 9091 "servicePort" (int .Values.service.port) "protocol" "TCP")) -}}
{{- end -}}

{{- define "pushgateway.pvcName" -}}
{{- .Values.persistence.existingClaim | default (include "quench-common.fullname" .) -}}
{{- end -}}

{{/* exporter-toolkit web config: TLS on the listener when tls.enabled. */}}
{{- define "pushgateway.webConfig" -}}
tls_server_config:
  cert_file: /tls/tls.crt
  key_file: /tls/tls.key
{{- end -}}
