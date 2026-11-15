{{/* Every port AdGuard Home listens on, as {name, port, servicePort, protocol}: container, Service and NetworkPolicy. */}}
{{- define "adguardhome.ports" -}}
{{- toJson (list
  (dict "name" "http" "port" 3000 "servicePort" (int .Values.service.port) "protocol" "TCP")
  (dict "name" "dns-udp" "port" 5353 "servicePort" (int .Values.service.dnsPort) "protocol" "UDP")
  (dict "name" "dns-tcp" "port" 5353 "servicePort" (int .Values.service.dnsPort) "protocol" "TCP")) -}}
{{- end -}}

{{- define "adguardhome.pvcName" -}}
{{- .Values.persistence.existingClaim | default (include "quench-common.fullname" .) -}}
{{- end -}}

{{- define "adguardhome.secretName" -}}
{{- .Values.admin.existingSecret | default (include "quench-common.fullname" .) -}}
{{- end -}}

{{- define "adguardhome.busybox" -}}
{{- printf "%s@%s" .Values.busybox.repository .Values.busybox.digest -}}
{{- end -}}
