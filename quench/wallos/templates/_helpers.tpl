{{/* Every port Wallos listens on, as {name, port, servicePort, protocol}: container, Service and NetworkPolicy. */}}
{{- define "wallos.ports" -}}
{{- toJson (list (dict "name" (ternary "https" "http" (eq (include "quench-common.tls.enabled" .) "true")) "port" 8080 "servicePort" (int .Values.service.port) "protocol" "TCP")) -}}
{{- end -}}

{{- define "wallos.pvcName" -}}
{{- .Values.persistence.existingClaim | default (include "quench-common.fullname" .) -}}
{{- end -}}

{{- define "wallos.env" -}}
- { name: WALLOS_ADMIN_USERNAME, value: {{ .Values.admin.username | quote }} }
- { name: WALLOS_ADMIN_EMAIL, value: {{ .Values.admin.email | quote }} }
- { name: WALLOS_ADMIN_CURRENCY, value: {{ .Values.admin.currency | quote }} }
- { name: WALLOS_ADMIN_LANGUAGE, value: {{ .Values.admin.language | quote }} }
- name: WALLOS_ADMIN_PASSWORD
  valueFrom:
    secretKeyRef: { name: {{ include "quench-common.fullname" . }}, key: admin-password }
{{- end -}}
