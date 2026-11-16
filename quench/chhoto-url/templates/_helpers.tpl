{{/* Every port the server listens on, as {name, port, servicePort, protocol}: container, Service and NetworkPolicy. */}}
{{- define "chhoto-url.ports" -}}
{{- toJson (list (dict "name" "http" "port" 4567 "servicePort" (int .Values.service.port) "protocol" "TCP")) -}}
{{- end -}}

{{- define "chhoto-url.pvcName" -}}
{{- .Values.persistence.existingClaim | default (include "quench-common.fullname" .) -}}
{{- end -}}

{{- define "chhoto-url.secretName" -}}
{{- .Values.auth.existingSecret | default (include "quench-common.fullname" .) -}}
{{- end -}}

{{/* CHHOTO_* settings (the image already sets CHHOTO_DB_URL). */}}
{{- define "chhoto-url.env" -}}
- name: CHHOTO_PASSWORD
  valueFrom:
    secretKeyRef: { name: {{ include "chhoto-url.secretName" . }}, key: password }
- name: CHHOTO_API_KEY
  valueFrom:
    secretKeyRef: { name: {{ include "chhoto-url.secretName" . }}, key: api-key }
{{- with .Values.siteUrl }}
- { name: CHHOTO_SITE_URL, value: {{ . | quote }} }
{{- end }}
{{- range $k, $v := .Values.settings }}
- { name: {{ $k }}, value: {{ $v | quote }} }
{{- end }}
{{- end -}}
