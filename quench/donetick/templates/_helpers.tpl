{{/* Every port the server listens on, as {name, port, servicePort, protocol}: container, Service and NetworkPolicy. */}}
{{- define "donetick.ports" -}}
{{- toJson (list (dict "name" "http" "port" 2021 "servicePort" (int .Values.service.port) "protocol" "TCP")) -}}
{{- end -}}

{{- define "donetick.pvcName" -}}
{{- .Values.persistence.existingClaim | default (include "quench-common.fullname" .) -}}
{{- end -}}

{{- define "donetick.secretName" -}}
{{- .Values.jwt.existingSecret | default (include "quench-common.fullname" .) -}}
{{- end -}}

{{/* donetick settings: DT_<SECTION>_<KEY> overrides the generated config/selfhosted.yaml. */}}
{{- define "donetick.env" -}}
- name: DT_JWT_SECRET
  valueFrom:
    secretKeyRef: { name: {{ include "donetick.secretName" . }}, key: jwt-secret }
{{- with .Values.publicUrl }}
- { name: DT_SERVER_PUBLIC_HOST, value: {{ . | quote }} }
{{- end }}
{{- if not .Values.signups }}
- { name: DONETICK_DISABLE_SIGNUP, value: "true" }
{{- end }}
{{- range $k, $v := .Values.settings }}
- { name: {{ $k }}, value: {{ $v | quote }} }
{{- end }}
{{- end -}}
