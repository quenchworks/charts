{{/* Every port Nebula listens on, as {name, port, servicePort, protocol}: container, Service and NetworkPolicy. */}}
{{- define "nebula.ports" -}}
{{- $p := list (dict "name" "nebula" "port" (int .Values.port) "servicePort" (int .Values.port) "protocol" "UDP") -}}
{{- if .Values.metrics.enabled }}{{ $p = append $p (dict "name" "metrics" "port" 8080 "servicePort" 8080 "protocol" "TCP") }}{{ end -}}
{{- toJson $p -}}
{{- end -}}

{{/* config.yml: the user's config with the PKI paths, listener and TUN setting the chart owns laid over it. */}}
{{- define "nebula.config" -}}
{{- $own := dict
  "pki" (dict "ca" "/pki/ca.crt" "cert" "/pki/host.crt" "key" "/pki/host.key")
  "listen" (dict "host" "0.0.0.0" "port" (int .Values.port))
  "lighthouse" (dict "am_lighthouse" true "interval" 60)
  "tun" (dict "disabled" true) -}}
{{- if .Values.metrics.enabled }}{{ $_ := set $own "stats" (dict "type" "prometheus" "listen" "0.0.0.0:8080" "path" "/metrics" "namespace" "nebula" "interval" "10s") }}{{ end -}}
{{- toYaml (mergeOverwrite (deepCopy .Values.config) $own) -}}
{{- end -}}
