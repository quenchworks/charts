{{/* Every port GoToSocial listens on, as {name, port, servicePort, protocol}: container, Service and NetworkPolicy. */}}
{{- define "gotosocial.ports" -}}
{{- toJson (list (dict "name" (ternary "https" "http" (eq (include "quench-common.tls.enabled" .) "true")) "port" 8080 "servicePort" (int .Values.service.port) "protocol" "TCP")) -}}
{{- end -}}

{{- define "gotosocial.pvcName" -}}
{{- .Values.persistence.existingClaim | default (include "quench-common.fullname" .) -}}
{{- end -}}

{{- define "gotosocial.secretName" -}}
{{- .Values.admin.existingSecret | default (include "quench-common.fullname" .) -}}
{{- end -}}

{{/* GTS_* settings (config keys as environment variables). */}}
{{- define "gotosocial.env" -}}
- { name: GTS_HOST, value: {{ required "host is required: the instance's domain, e.g. social.example.com (it cannot change later)" .Values.host | quote }} }
{{- with .Values.accountDomain }}
- { name: GTS_ACCOUNT_DOMAIN, value: {{ . | quote }} }
{{- end }}
- { name: GTS_PROTOCOL, value: {{ .Values.protocol | quote }} }
- { name: GTS_ACCOUNTS_REGISTRATION_OPEN, value: {{ .Values.registrationOpen | quote }} }
{{- with .Values.trustedProxies }}
- { name: GTS_TRUSTED_PROXIES, value: {{ join "," . | quote }} }
{{- end }}
{{- if include "quench-common.tls.enabled" . }}
- { name: GTS_TLS_CERTIFICATE_CHAIN, value: /tls/tls.crt }
- { name: GTS_TLS_CERTIFICATE_KEY, value: /tls/tls.key }
{{- end }}
{{- range $k, $v := .Values.settings }}
- { name: {{ $k }}, value: {{ $v | quote }} }
{{- end }}
{{- end -}}
