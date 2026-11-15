{{/* Every port rest-server listens on, as {name, port, servicePort, protocol}: container, Service and NetworkPolicy. */}}
{{- define "rest-server.ports" -}}
{{- toJson (list (dict "name" (ternary "https" "http" (eq (include "quench-common.tls.enabled" .) "true")) "port" 8000 "servicePort" (int .Values.service.port) "protocol" "TCP")) -}}
{{- end -}}

{{- define "rest-server.pvcName" -}}
{{- .Values.persistence.existingClaim | default (include "quench-common.fullname" .) -}}
{{- end -}}

{{- define "rest-server.secretName" -}}
{{- .Values.auth.existingSecret | default (include "quench-common.fullname" .) -}}
{{- end -}}

{{/* rest-server's command line. */}}
{{- define "rest-server.args" -}}
- --path=/data
- --listen=:8000
{{- if .Values.auth.enabled }}
- --htpasswd-file=/auth/.htpasswd
{{- else }}
- --no-auth
{{- end }}
{{- if .Values.appendOnly }}
- --append-only
{{- end }}
{{- if .Values.privateRepos }}
- --private-repos
{{- end }}
{{- if .Values.maxRepoSize }}
- --max-size={{ int64 .Values.maxRepoSize }}
{{- end }}
{{- if .Values.metrics.enabled }}
- --prometheus
{{- if .Values.metrics.noAuth }}
- --prometheus-no-auth
{{- end }}
{{- end }}
{{- if include "quench-common.tls.enabled" . }}
- --tls
- --tls-cert=/tls/tls.crt
- --tls-key=/tls/tls.key
{{- end }}
{{- range .Values.extraArgs }}
- {{ . | quote }}
{{- end }}
{{- end -}}
