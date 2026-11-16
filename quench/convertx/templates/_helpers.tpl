{{/* Every port the server listens on, as {name, port, servicePort, protocol}: container, Service and NetworkPolicy. */}}
{{- define "convertx.ports" -}}
{{- toJson (list (dict "name" "http" "port" 3000 "servicePort" (int .Values.service.port) "protocol" "TCP")) -}}
{{- end -}}

{{- define "convertx.pvcName" -}}
{{- .Values.persistence.existingClaim | default (include "quench-common.fullname" .) -}}
{{- end -}}

{{- define "convertx.secretName" -}}
{{- .Values.auth.existingSecret | default (include "quench-common.fullname" .) -}}
{{- end -}}

{{- define "convertx.env" -}}
- name: JWT_SECRET
  valueFrom:
    secretKeyRef: { name: {{ include "convertx.secretName" . }}, key: jwt-secret }
- { name: ACCOUNT_REGISTRATION, value: {{ .Values.accountRegistration | quote }} }
- { name: HTTP_ALLOWED, value: {{ .Values.httpAllowed | quote }} }
- { name: AUTO_DELETE_EVERY_N_HOURS, value: {{ .Values.autoDeleteEveryNHours | quote }} }
{{- range $k, $v := .Values.settings }}
- { name: {{ $k }}, value: {{ $v | quote }} }
{{- end }}
{{- end -}}
