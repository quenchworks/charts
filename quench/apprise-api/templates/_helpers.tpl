{{/* Every port the server listens on, as {name, port, servicePort, protocol}: container, Service and NetworkPolicy. */}}
{{- define "apprise-api.ports" -}}
{{- toJson (list (dict "name" "http" "port" 8000 "servicePort" (int .Values.service.port) "protocol" "TCP")) -}}
{{- end -}}

{{- define "apprise-api.pvcName" -}}
{{- .Values.persistence.existingClaim | default (include "quench-common.fullname" .) -}}
{{- end -}}

{{- define "apprise-api.secretName" -}}
{{- .Values.auth.existingSecret | default (include "quench-common.fullname" .) -}}
{{- end -}}

{{/* Apprise API settings: upstream's environment variables. */}}
{{- define "apprise-api.env" -}}
- name: SECRET_KEY
  valueFrom:
    secretKeyRef: { name: {{ include "apprise-api.secretName" . }}, key: secret-key }
{{- if .Values.auth.enabled }}
- { name: APPRISE_AUTH_REQUIRED, value: "yes" }
- { name: APPRISE_USER, value: {{ .Values.auth.username | quote }} }
- name: APPRISE_PASSWORD
  valueFrom:
    secretKeyRef: { name: {{ include "apprise-api.secretName" . }}, key: password }
{{- end }}
- { name: APPRISE_STATEFUL_MODE, value: {{ .Values.statefulMode | quote }} }
- { name: APPRISE_CONFIG_LOCK, value: {{ ternary "yes" "no" .Values.configLock | quote }} }
- { name: STRICT_MODE, value: {{ ternary "yes" "no" .Values.strictMode | quote }} }
- { name: APPRISE_WORKER_COUNT, value: {{ .Values.workers | quote }} }
{{- range $k, $v := .Values.settings }}
- { name: {{ $k }}, value: {{ $v | quote }} }
{{- end }}
{{- end -}}
