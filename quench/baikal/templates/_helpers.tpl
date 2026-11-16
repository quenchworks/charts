{{/* Every port Baikal listens on, as {name, port, servicePort, protocol}: container, Service and NetworkPolicy. */}}
{{- define "baikal.ports" -}}
{{- toJson (list (dict "name" (ternary "https" "http" (eq (include "quench-common.tls.enabled" .) "true")) "port" 8080 "servicePort" (int .Values.service.port) "protocol" "TCP")) -}}
{{- end -}}

{{- define "baikal.pvcName" -}}
{{- .Values.persistence.existingClaim | default (include "quench-common.fullname" .) -}}
{{- end -}}

{{- define "baikal.env" -}}
- name: BAIKAL_ADMIN_PASSWORD
  valueFrom:
    secretKeyRef: { name: {{ include "quench-common.fullname" . }}, key: admin-password }
- { name: BAIKAL_DAV_AUTH_TYPE, value: {{ .Values.davAuthType | quote }} }
- { name: BAIKAL_TIMEZONE, value: {{ .Values.timezone | quote }} }
{{- with .Values.davUser.username }}
- { name: BAIKAL_DAV_USER, value: {{ . | quote }} }
- { name: BAIKAL_DAV_EMAIL, value: {{ $.Values.davUser.email | default (printf "%s@example.com" .) | quote }} }
- name: BAIKAL_DAV_PASSWORD
  valueFrom:
    secretKeyRef: { name: {{ include "quench-common.fullname" $ }}, key: dav-password }
{{- end }}
{{- end -}}
