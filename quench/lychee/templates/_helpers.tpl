{{/* Every port Lychee listens on, as {name, port, servicePort, protocol}: container, Service and NetworkPolicy. */}}
{{- define "lychee.ports" -}}
{{- toJson (list (dict "name" (ternary "https" "http" (eq (include "quench-common.tls.enabled" .) "true")) "port" 8080 "servicePort" (int .Values.service.port) "protocol" "TCP")) -}}
{{- end -}}

{{- define "lychee.pvcName" -}}
{{- .Values.persistence.existingClaim | default (include "quench-common.fullname" .) -}}
{{- end -}}

{{- define "lychee.secretName" -}}
{{- .Values.appKey.existingSecret | default (include "quench-common.fullname" .) -}}
{{- end -}}

{{- define "lychee.env" -}}
- name: APP_KEY
  valueFrom:
    secretKeyRef: { name: {{ include "lychee.secretName" . }}, key: app-key }
{{- with .Values.appURL }}
- { name: APP_URL, value: {{ . | quote }} }
{{- end }}
- { name: ADMIN_USER, value: {{ .Values.admin.username | quote }} }
- name: ADMIN_PASSWORD
  valueFrom:
    secretKeyRef: { name: {{ include "quench-common.fullname" . }}, key: admin-password }
{{- range $k, $v := .Values.settings }}
- { name: {{ $k }}, value: {{ $v | quote }} }
{{- end }}
{{- end -}}
