{{/* Every port Ergo listens on, as {name, port, servicePort, protocol}: container, Service and NetworkPolicy. */}}
{{- define "ergo.ports" -}}
{{- $p := list (dict "name" "irc" "port" 6667 "servicePort" (int .Values.service.port) "protocol" "TCP") -}}
{{- if include "quench-common.tls.enabled" . -}}
{{- $p = append $p (dict "name" "ircs" "port" 6697 "servicePort" (int .Values.service.tlsPort) "protocol" "TCP") -}}
{{- end -}}
{{- toJson $p -}}
{{- end -}}

{{- define "ergo.pvcName" -}}
{{- .Values.persistence.existingClaim | default (include "quench-common.fullname" .) -}}
{{- end -}}

{{- define "ergo.secretName" -}}
{{- .Values.oper.existingSecret | default (include "quench-common.fullname" .) -}}
{{- end -}}

{{/* The listeners map as YAML for ERGO__SERVER__LISTENERS: plain IRC, plus TLS on 6697 with a certificate. */}}
{{- define "ergo.listeners" -}}
{{- $l := dict ":6667" (dict) -}}
{{- if include "quench-common.tls.enabled" . -}}
{{- $_ := set $l ":6697" (dict "tls" (dict "cert" "/tls/tls.crt" "key" "/tls/tls.key") "min-tls-version" "1.2") -}}
{{- end -}}
{{- toJson $l -}}
{{- end -}}
