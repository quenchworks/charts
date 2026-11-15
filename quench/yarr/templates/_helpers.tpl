{{/* Every port yarr listens on, as {name, port, servicePort, protocol}: container, Service and NetworkPolicy. */}}
{{- define "yarr.ports" -}}
{{- toJson (list (dict "name" (ternary "https" "http" (eq (include "quench-common.tls.enabled" .) "true")) "port" 7070 "servicePort" (int .Values.service.port) "protocol" "TCP")) -}}
{{- end -}}

{{- define "yarr.pvcName" -}}
{{- .Values.persistence.existingClaim | default (include "quench-common.fullname" .) -}}
{{- end -}}

{{- define "yarr.secretName" -}}
{{- .Values.auth.existingSecret | default (include "quench-common.fullname" .) -}}
{{- end -}}

{{/* The app environment. */}}
{{- define "yarr.env" -}}
{{- with .Values.basePath }}
- { name: YARR_BASE, value: {{ . | quote }} }
{{- end }}
{{- if .Values.auth.enabled }}
# the login as username:password; YARR_AUTHFILE would put it on disk instead
- name: YARR_AUTH
  valueFrom:
    secretKeyRef:
      name: {{ include "yarr.secretName" . }}
      key: auth
{{- end }}
{{- range $k, $v := .Values.settings }}
- { name: {{ $k }}, value: {{ $v | quote }} }
{{- end }}
{{ include "quench-common.extraEnvVars" . }}
{{- end -}}
