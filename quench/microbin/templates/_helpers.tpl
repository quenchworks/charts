{{/* Every port the server listens on, as {name, port, servicePort, protocol}: container, Service and NetworkPolicy. */}}
{{- define "microbin.ports" -}}
{{- toJson (list (dict "name" "http" "port" 8080 "servicePort" (int .Values.service.port) "protocol" "TCP")) -}}
{{- end -}}

{{- define "microbin.pvcName" -}}
{{- .Values.persistence.existingClaim | default (include "quench-common.fullname" .) -}}
{{- end -}}

{{- define "microbin.secretName" -}}
{{- .Values.admin.existingSecret | default (include "quench-common.fullname" .) -}}
{{- end -}}

{{/* MICROBIN_* settings (the image already sets the data dir, port, and turns telemetry and update checks off). */}}
{{- define "microbin.env" -}}
- { name: MICROBIN_ADMIN_USERNAME, value: {{ .Values.admin.username | quote }} }
- name: MICROBIN_ADMIN_PASSWORD
  valueFrom:
    secretKeyRef: { name: {{ include "microbin.secretName" . }}, key: password }
{{- with .Values.publicPath }}
- { name: MICROBIN_PUBLIC_PATH, value: {{ . | quote }} }
{{- end }}
{{- range $k, $v := .Values.settings }}
- { name: {{ $k }}, value: {{ $v | quote }} }
{{- end }}
{{- end -}}
