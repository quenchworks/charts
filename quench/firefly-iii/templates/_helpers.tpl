{{/* Every port Firefly III listens on, as {name, port, servicePort, protocol}: container, Service and NetworkPolicy. */}}
{{- define "firefly-iii.ports" -}}
{{- toJson (list (dict "name" (ternary "https" "http" (eq (include "quench-common.tls.enabled" .) "true")) "port" 8080 "servicePort" (int .Values.service.port) "protocol" "TCP")) -}}
{{- end -}}

{{- define "firefly-iii.pvcName" -}}
{{- .Values.persistence.existingClaim | default (include "quench-common.fullname" .) -}}
{{- end -}}

{{- define "firefly-iii.secretName" -}}
{{- .Values.appKey.existingSecret | default (include "quench-common.fullname" .) -}}
{{- end -}}

{{- define "firefly-iii.env" -}}
- name: APP_KEY
  valueFrom:
    secretKeyRef: { name: {{ include "firefly-iii.secretName" . }}, key: app-key }
{{- with .Values.appURL }}
- { name: APP_URL, value: {{ . | quote }} }
{{- end }}
{{- with .Values.trustedProxies }}
- { name: TRUSTED_PROXIES, value: {{ . | quote }} }
{{- end }}
{{- range $k, $v := .Values.settings }}
- { name: {{ $k }}, value: {{ $v | quote }} }
{{- end }}
{{- end -}}
