{{/* Every port Kopia listens on, as {name, port, servicePort, protocol}: container, Service and NetworkPolicy. */}}
{{- define "kopia.ports" -}}
{{- toJson (list (dict "name" (ternary "https" "http" (eq (include "quench-common.tls.enabled" .) "true")) "port" 51515 "servicePort" (int .Values.service.port) "protocol" "TCP")) -}}
{{- end -}}

{{- define "kopia.pvcName" -}}
{{- .Values.persistence.existingClaim | default (include "quench-common.fullname" .) -}}
{{- end -}}

{{- define "kopia.secretName" -}}
{{- .Values.existingSecret | default (include "quench-common.fullname" .) -}}
{{- end -}}

{{/* The environment the repository init container and the server share. */}}
{{- define "kopia.env" -}}
- name: KOPIA_PASSWORD
  valueFrom:
    secretKeyRef:
      name: {{ include "kopia.secretName" . }}
      key: repository-password
{{- range $k, $v := .Values.settings }}
- { name: {{ $k }}, value: {{ $v | quote }} }
{{- end }}
{{ include "quench-common.extraEnvVars" . }}
{{- end -}}
