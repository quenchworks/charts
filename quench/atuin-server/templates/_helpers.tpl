{{/* Every port the server listens on, as {name, port, servicePort, protocol}: container, Service and NetworkPolicy. */}}
{{- define "atuin-server.ports" -}}
{{- toJson (list (dict "name" "http" "port" 8888 "servicePort" (int .Values.service.port) "protocol" "TCP")) -}}
{{- end -}}

{{- define "atuin-server.pvcName" -}}
{{- .Values.persistence.existingClaim | default (include "quench-common.fullname" .) -}}
{{- end -}}

{{- define "atuin-server.secretName" -}}
{{- .Values.admin.existingSecret | default (include "quench-common.fullname" .) -}}
{{- end -}}

{{/* ATUIN_* settings shared by the server and the admin init container. */}}
{{- define "atuin-server.env" -}}
- { name: ATUIN_OPEN_REGISTRATION, value: {{ .Values.openRegistration | quote }} }
- { name: ATUIN_MAX_RECORD_SIZE, value: {{ .Values.maxRecordSize | quote }} }
{{- range $k, $v := .Values.settings }}
- { name: {{ $k }}, value: {{ $v | quote }} }
{{- end }}
{{- end -}}
