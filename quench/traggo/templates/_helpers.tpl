{{/* Every port the server listens on, as {name, port, servicePort, protocol}: container, Service and NetworkPolicy. */}}
{{- define "traggo.ports" -}}
{{- toJson (list (dict "name" "http" "port" 3030 "servicePort" (int .Values.service.port) "protocol" "TCP")) -}}
{{- end -}}

{{- define "traggo.pvcName" -}}
{{- .Values.persistence.existingClaim | default (include "quench-common.fullname" .) -}}
{{- end -}}

{{- define "traggo.secretName" -}}
{{- .Values.auth.existingSecret | default (include "quench-common.fullname" .) -}}
{{- end -}}

{{/* traggo settings: TRAGGO_* environment variables. The first admin is created from these when the database has no
     users (upstream defaults to admin/admin, so the chart always sets them). */}}
{{- define "traggo.env" -}}
- { name: TRAGGO_DEFAULT_USER_NAME, value: {{ .Values.auth.username | quote }} }
- name: TRAGGO_DEFAULT_USER_PASS
  valueFrom:
    secretKeyRef: { name: {{ include "traggo.secretName" . }}, key: password }
{{- range $k, $v := .Values.settings }}
- { name: {{ $k }}, value: {{ $v | quote }} }
{{- end }}
{{- end -}}
