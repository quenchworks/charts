{{/* Every port Readeck listens on, as {name, port, servicePort, protocol}: container, Service and NetworkPolicy. */}}
{{- define "readeck.ports" -}}
{{- toJson (list (dict "name" (ternary "https" "http" (eq (include "quench-common.tls.enabled" .) "true")) "port" 8000 "servicePort" (int .Values.service.port) "protocol" "TCP")) -}}
{{- end -}}

{{- define "readeck.pvcName" -}}
{{- .Values.persistence.existingClaim | default (include "quench-common.fullname" .) -}}
{{- end -}}

{{- define "readeck.secretName" -}}
{{- .Values.admin.existingSecret | default (include "quench-common.fullname" .) -}}
{{- end -}}

{{/* READECK_* settings shared by the server and the admin init container. */}}
{{- define "readeck.env" -}}
{{- with .Values.baseURL }}
- { name: READECK_SERVER_BASE_URL, value: {{ . | quote }} }
{{- end }}
{{- with .Values.allowedHosts }}
- { name: READECK_ALLOWED_HOSTS, value: {{ join "," . | quote }} }
{{- end }}
{{- with .Values.trustedProxies }}
- { name: READECK_TRUSTED_PROXIES, value: {{ join "," . | quote }} }
{{- end }}
{{- if include "quench-common.tls.enabled" . }}
- { name: READECK_CERT_FILE, value: /tls/tls.crt }
- { name: READECK_KEY_FILE, value: /tls/tls.key }
{{- end }}
{{- range $k, $v := .Values.settings }}
- { name: {{ $k }}, value: {{ $v | quote }} }
{{- end }}
{{- end -}}
