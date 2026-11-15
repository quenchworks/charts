{{/* Every port the server listens on, as {name, port, servicePort, protocol}: container, Service and NetworkPolicy. */}}
{{- define "wstunnel.ports" -}}
{{- toJson (list (dict "name" (ternary "wss" "ws" (eq (include "quench-common.tls.enabled" .) "true")) "port" 8080 "servicePort" (int .Values.service.port) "protocol" "TCP")) -}}
{{- end -}}

{{- define "wstunnel.secretName" -}}
{{- .Values.pathPrefix.existingSecret | default (include "quench-common.fullname" .) -}}
{{- end -}}

{{/* The server command line. The path prefix comes from the Secret through $(PATH_PREFIX). */}}
{{- define "wstunnel.args" -}}
- server
- {{ ternary "wss" "ws" (eq (include "quench-common.tls.enabled" .) "true") }}://0.0.0.0:8080
{{- if .Values.pathPrefix.enabled }}
- --restrict-http-upgrade-path-prefix=$(PATH_PREFIX)
{{- end }}
{{- range .Values.restrictTo }}
- --restrict-to={{ . }}
{{- end }}
{{- if include "quench-common.tls.enabled" . }}
- --tls-certificate=/tls/tls.crt
- --tls-private-key=/tls/tls.key
{{- end }}
{{- range .Values.extraArgs }}
- {{ . | quote }}
{{- end }}
{{- end -}}
