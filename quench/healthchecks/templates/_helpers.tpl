{{/* Every port Healthchecks listens on, as {name, port, servicePort, protocol}: container, Service and NetworkPolicy. */}}
{{- define "healthchecks.ports" -}}
{{- toJson (list (dict "name" (ternary "https" "http" (eq (include "quench-common.tls.enabled" .) "true")) "port" 8000 "servicePort" (int .Values.service.port) "protocol" "TCP")) -}}
{{- end -}}

{{- define "healthchecks.pvcName" -}}
{{- .Values.persistence.existingClaim | default (include "quench-common.fullname" .) -}}
{{- end -}}

{{- define "healthchecks.secretName" -}}
{{- .Values.admin.existingSecret | default (include "quench-common.fullname" .) -}}
{{- end -}}

{{/* The environment the app and the admin init container share. */}}
{{- define "healthchecks.env" -}}
- { name: SITE_ROOT, value: {{ .Values.siteRoot | quote }} }
- name: SECRET_KEY
  valueFrom:
    secretKeyRef:
      name: {{ include "quench-common.fullname" . }}
      key: secret-key
{{- range $k, $v := .Values.settings }}
- { name: {{ $k }}, value: {{ $v | quote }} }
{{- end }}
{{ include "quench-common.extraEnvVars" . }}
{{- end -}}
