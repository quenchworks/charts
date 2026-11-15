{{/* Every port dufs listens on, as {name, port, servicePort, protocol}: container, Service and NetworkPolicy. */}}
{{- define "dufs.ports" -}}
{{- toJson (list (dict "name" (ternary "https" "http" (eq (include "quench-common.tls.enabled" .) "true")) "port" 5000 "servicePort" (int .Values.service.port) "protocol" "TCP")) -}}
{{- end -}}

{{- define "dufs.pvcName" -}}
{{- .Values.persistence.existingClaim | default (include "quench-common.fullname" .) -}}
{{- end -}}

{{- define "dufs.secretName" -}}
{{- .Values.auth.existingSecret | default (include "quench-common.fullname" .) -}}
{{- end -}}

{{/* The app environment. */}}
{{- define "dufs.env" -}}
{{- if .Values.auth.enabled }}
# DUFS_AUTH: user:password@/path:rw rules, from the Secret
- name: DUFS_AUTH
  valueFrom:
    secretKeyRef:
      name: {{ include "dufs.secretName" . }}
      key: auth
{{- end }}
- { name: DUFS_ALLOW_UPLOAD, value: {{ .Values.allow.upload | quote }} }
- { name: DUFS_ALLOW_DELETE, value: {{ .Values.allow.delete | quote }} }
- { name: DUFS_ALLOW_SEARCH, value: {{ .Values.allow.search | quote }} }
- { name: DUFS_ALLOW_ARCHIVE, value: {{ .Values.allow.archive | quote }} }
{{- range $k, $v := .Values.settings }}
- { name: {{ $k }}, value: {{ $v | quote }} }
{{- end }}
{{ include "quench-common.extraEnvVars" . }}
{{- end -}}
