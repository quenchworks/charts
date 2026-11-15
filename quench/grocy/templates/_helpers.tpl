{{/* Every port Grocy listens on, as {name, port, servicePort, protocol}: container, Service and NetworkPolicy. */}}
{{- define "grocy.ports" -}}
{{- toJson (list (dict "name" (ternary "https" "http" (eq (include "quench-common.tls.enabled" .) "true")) "port" 8080 "servicePort" (int .Values.service.port) "protocol" "TCP")) -}}
{{- end -}}

{{- define "grocy.pvcName" -}}
{{- .Values.persistence.existingClaim | default (include "quench-common.fullname" .) -}}
{{- end -}}

{{- define "grocy.secretName" -}}
{{- .Values.admin.existingSecret | default (include "quench-common.fullname" .) -}}
{{- end -}}

{{/* GROCY_* settings. GROCY_HTTP_USER/PASSWORD name the first user; Grocy reads them once, when it
     creates the database, so a later password change is made in the UI. */}}
{{- define "grocy.env" -}}
- { name: GROCY_HTTP_USER, value: {{ .Values.admin.username | quote }} }
- name: GROCY_HTTP_PASSWORD
  valueFrom:
    secretKeyRef: { name: {{ include "grocy.secretName" . }}, key: password }
- { name: GROCY_CURRENCY, value: {{ .Values.currency | quote }} }
- { name: GROCY_DEFAULT_LOCALE, value: {{ .Values.locale | quote }} }
{{- with .Values.baseURL }}
- { name: GROCY_BASE_URL, value: {{ . | quote }} }
{{- end }}
{{- range $k, $v := .Values.settings }}
- { name: {{ $k }}, value: {{ $v | quote }} }
{{- end }}
{{- end -}}
