{{/* Every port go-httpbin listens on, as {name, port, servicePort, protocol}: container, Service and NetworkPolicy. */}}
{{- define "go-httpbin.ports" -}}
{{- toJson (list (dict "name" (ternary "https" "http" (eq (include "quench-common.tls.enabled" .) "true")) "port" 8080 "servicePort" (int .Values.service.port) "protocol" "TCP")) -}}
{{- end -}}

{{/* go-httpbin's command line. */}}
{{- define "go-httpbin.args" -}}
- -port=8080
{{- with .Values.maxBodySize }}
- -max-body-size={{ int64 . }}
{{- end }}
{{- with .Values.maxDuration }}
- -max-duration={{ . }}
{{- end }}
{{- with .Values.allowedRedirectDomains }}
- -allowed-redirect-domains={{ join "," . }}
{{- end }}
{{- if .Values.fullVersion }}
- -use-full-version
{{- end }}
{{- if include "quench-common.tls.enabled" . }}
- -https-cert-file=/tls/tls.crt
- -https-key-file=/tls/tls.key
{{- end }}
{{- range .Values.extraArgs }}
- {{ . | quote }}
{{- end }}
{{- end -}}
