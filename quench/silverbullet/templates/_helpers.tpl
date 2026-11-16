{{/* Every port the server listens on, as {name, port, servicePort, protocol}: container, Service and NetworkPolicy. */}}
{{- define "silverbullet.ports" -}}
{{- toJson (list (dict "name" "http" "port" 3000 "servicePort" (int .Values.service.port) "protocol" "TCP")) -}}
{{- end -}}

{{- define "silverbullet.pvcName" -}}
{{- .Values.persistence.existingClaim | default (include "quench-common.fullname" .) -}}
{{- end -}}

{{- define "silverbullet.secretName" -}}
{{- .Values.auth.existingSecret | default (include "quench-common.fullname" .) -}}
{{- end -}}

{{/* SilverBullet settings: SB_USER is user:password (Kubernetes $(VAR) expansion joins them), SB_AUTH_TOKEN the API
     bearer token. */}}
{{- define "silverbullet.env" -}}
{{- if .Values.auth.enabled }}
- name: SB_PASSWORD
  valueFrom:
    secretKeyRef: { name: {{ include "silverbullet.secretName" . }}, key: password }
- { name: SB_USER, value: "{{ .Values.auth.username }}:$(SB_PASSWORD)" }
- name: SB_AUTH_TOKEN
  valueFrom:
    secretKeyRef: { name: {{ include "silverbullet.secretName" . }}, key: api-token }
{{- end }}
{{- range $k, $v := .Values.settings }}
- { name: {{ $k }}, value: {{ $v | quote }} }
{{- end }}
{{- end -}}
