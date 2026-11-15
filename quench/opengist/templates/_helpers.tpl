{{/* Every port Opengist listens on, as {name, port, servicePort, protocol}: container, Service and NetworkPolicy. */}}
{{- define "opengist.ports" -}}
{{- $p := list (dict "name" "http" "port" 6157 "servicePort" (int .Values.service.port) "protocol" "TCP") -}}
{{- if .Values.ssh.enabled -}}
{{- $p = append $p (dict "name" "ssh" "port" 2222 "servicePort" (int .Values.ssh.servicePort) "protocol" "TCP") -}}
{{- end -}}
{{- toJson $p -}}
{{- end -}}

{{- define "opengist.pvcName" -}}
{{- .Values.persistence.existingClaim | default (include "quench-common.fullname" .) -}}
{{- end -}}

{{- define "opengist.secretName" -}}
{{- .Values.admin.existingSecret | default (printf "%s-admin" (include "quench-common.fullname" .)) -}}
{{- end -}}

{{/* OG_* settings shared by the server and the admin-seeding init container. */}}
{{- define "opengist.env" -}}
- { name: OG_OPENGIST_HOME, value: /opengist }
- { name: OG_HTTP_PORT, value: "6157" }
- { name: OG_SSH_GIT_ENABLED, value: {{ .Values.ssh.enabled | quote }} }
{{- if .Values.ssh.enabled }}
- { name: OG_SSH_PORT, value: "2222" }
{{- end }}
{{- with .Values.database.existingSecret }}
- name: OG_DB_URI
  valueFrom:
    secretKeyRef:
      name: {{ . }}
      key: {{ $.Values.database.uriKey }}
{{- end }}
{{- range $k, $v := .Values.settings }}
- { name: {{ $k }}, value: {{ $v | quote }} }
{{- end }}
{{- end -}}
