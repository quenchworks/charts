{{/* Every port Koel listens on, as {name, port, servicePort, protocol}: container, Service and NetworkPolicy. */}}
{{- define "koel.ports" -}}
{{- toJson (list (dict "name" (ternary "https" "http" (eq (include "quench-common.tls.enabled" .) "true")) "port" 8080 "servicePort" (int .Values.service.port) "protocol" "TCP")) -}}
{{- end -}}

{{- define "koel.pvcName" -}}
{{- .Values.persistence.existingClaim | default (include "quench-common.fullname" .) -}}
{{- end -}}

{{- define "koel.secretName" -}}
{{- .Values.appKey.existingSecret | default (include "quench-common.fullname" .) -}}
{{- end -}}

{{- define "koel.env" -}}
- name: APP_KEY
  valueFrom:
    secretKeyRef: { name: {{ include "koel.secretName" . }}, key: app-key }
{{- with .Values.appURL }}
- { name: APP_URL, value: {{ . | quote }} }
{{- end }}
- { name: ADMIN_NAME, value: {{ .Values.admin.name | quote }} }
- { name: ADMIN_EMAIL, value: {{ .Values.admin.email | quote }} }
- name: ADMIN_PASSWORD
  valueFrom:
    secretKeyRef: { name: {{ include "quench-common.fullname" . }}, key: admin-password }
{{- range $k, $v := .Values.settings }}
- { name: {{ $k }}, value: {{ $v | quote }} }
{{- end }}
{{- end -}}
