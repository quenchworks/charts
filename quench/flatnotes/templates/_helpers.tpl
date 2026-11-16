{{/* Every port the server listens on, as {name, port, servicePort, protocol}: container, Service and NetworkPolicy. */}}
{{- define "flatnotes.ports" -}}
{{- toJson (list (dict "name" "http" "port" 8080 "servicePort" (int .Values.service.port) "protocol" "TCP")) -}}
{{- end -}}

{{- define "flatnotes.pvcName" -}}
{{- .Values.persistence.existingClaim | default (include "quench-common.fullname" .) -}}
{{- end -}}

{{- define "flatnotes.secretName" -}}
{{- .Values.auth.existingSecret | default (include "quench-common.fullname" .) -}}
{{- end -}}

{{/* flatnotes settings: FLATNOTES_* environment variables. */}}
{{- define "flatnotes.env" -}}
- { name: FLATNOTES_AUTH_TYPE, value: {{ .Values.auth.type | quote }} }
{{- if has .Values.auth.type (list "password" "totp") }}
- { name: FLATNOTES_USERNAME, value: {{ .Values.auth.username | quote }} }
- name: FLATNOTES_PASSWORD
  valueFrom:
    secretKeyRef: { name: {{ include "flatnotes.secretName" . }}, key: password }
- name: FLATNOTES_SECRET_KEY
  valueFrom:
    secretKeyRef: { name: {{ include "flatnotes.secretName" . }}, key: secret-key }
{{- end }}
{{- if eq .Values.auth.type "totp" }}
- name: FLATNOTES_TOTP_KEY
  valueFrom:
    secretKeyRef: { name: {{ include "flatnotes.secretName" . }}, key: totp-key }
{{- end }}
{{- range $k, $v := .Values.settings }}
- { name: {{ $k }}, value: {{ $v | quote }} }
{{- end }}
{{- end -}}
