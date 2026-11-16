{{/* Every port Grav listens on, as {name, port, servicePort, protocol}: container, Service and NetworkPolicy. */}}
{{- define "grav.ports" -}}
{{- toJson (list (dict "name" (ternary "https" "http" (eq (include "quench-common.tls.enabled" .) "true")) "port" 8080 "servicePort" (int .Values.service.port) "protocol" "TCP")) -}}
{{- end -}}

{{- define "grav.pvcName" -}}
{{- .Values.persistence.existingClaim | default (include "quench-common.fullname" .) -}}
{{- end -}}

{{- define "grav.env" -}}
- { name: GRAV_ADMIN_USER, value: {{ .Values.admin.username | quote }} }
- { name: GRAV_ADMIN_EMAIL, value: {{ .Values.admin.email | quote }} }
- { name: GRAV_ADMIN_FULLNAME, value: {{ .Values.admin.fullname | quote }} }
- name: GRAV_ADMIN_PASSWORD
  valueFrom:
    secretKeyRef: { name: {{ include "quench-common.fullname" . }}, key: admin-password }
{{- end -}}
