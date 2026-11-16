{{/* Every port Shaarli listens on, as {name, port, servicePort, protocol}: container, Service and NetworkPolicy. */}}
{{- define "shaarli.ports" -}}
{{- toJson (list (dict "name" (ternary "https" "http" (eq (include "quench-common.tls.enabled" .) "true")) "port" 8080 "servicePort" (int .Values.service.port) "protocol" "TCP")) -}}
{{- end -}}

{{- define "shaarli.pvcName" -}}
{{- .Values.persistence.existingClaim | default (include "quench-common.fullname" .) -}}
{{- end -}}

{{- define "shaarli.env" -}}
- { name: SHAARLI_USER, value: {{ .Values.user.login | quote }} }
- name: SHAARLI_PASSWORD
  valueFrom:
    secretKeyRef: { name: {{ include "quench-common.fullname" . }}, key: password }
- name: SHAARLI_API_SECRET
  valueFrom:
    secretKeyRef: { name: {{ include "quench-common.fullname" . }}, key: api-secret }
- { name: SHAARLI_TITLE, value: {{ .Values.title | quote }} }
- { name: SHAARLI_TIMEZONE, value: {{ .Values.timezone | quote }} }
{{- end -}}
