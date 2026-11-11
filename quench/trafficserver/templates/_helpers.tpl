{{- define "trafficserver.serviceAccountName" -}}
{{- if .Values.serviceAccount.create -}}{{ default (include "quench-common.fullname" .) .Values.serviceAccount.name }}{{- else -}}{{ default "default" .Values.serviceAccount.name }}{{- end -}}
{{- end -}}

{{- define "trafficserver.configMapName" -}}
{{- printf "%s-config" (include "quench-common.fullname" .) -}}
{{- end -}}

{{/* The config files the chart owns, one key each (mounted by subPath, so the rest of
     /etc/trafficserver keeps the image's defaults). */}}
{{- define "trafficserver.files" -}}
remap.config: |
  {{- range .Values.remap }}
  {{ . }}
  {{- end }}
storage.config: |
  /var/cache/trafficserver {{ .Values.cache.size }}
# The kubelet probes /__hc, which the healthchecks plugin answers from memory before remap,
# so a probe does not depend on any remap rule or origin.
plugin.config: |
  healthchecks.so /etc/trafficserver/healthchecks.config
healthchecks.config: |
  /__hc /etc/trafficserver/hc-ok text/plain 200 503
hc-ok: |
  ok
{{- if include "quench-common.tls.enabled" . }}
ssl_multicert.config: |
  dest_ip=* ssl_cert_name=/tls/tls.crt ssl_key_name=/tls/tls.key
{{- end }}
{{- end -}}

{{/* records overrides as PROXY_CONFIG_* env. server_ports is always set: the TLS listener
     joins it when tls.enabled. */}}
{{- define "trafficserver.recordsEnv" -}}
{{- $ports := printf "%d %d:ipv6" 8080 8080 -}}
{{- if include "quench-common.tls.enabled" . -}}
{{- $ports = printf "%s %d:ssl %d:ssl:ipv6" $ports (int .Values.service.tlsPort) (int .Values.service.tlsPort) -}}
{{- end -}}
{{- $records := merge (dict) .Values.records (dict "proxy.config.http.server_ports" $ports) -}}
{{- range $k, $v := $records }}
- name: {{ $k | trimPrefix "proxy.config." | replace "." "_" | upper | printf "PROXY_CONFIG_%s" }}
  value: {{ $v | toString | quote }}
{{- end }}
{{- end -}}
