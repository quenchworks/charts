{{/* Every port the server listens on, as {name, port, servicePort, protocol}: container, Service and NetworkPolicy. */}}
{{- define "copyparty.ports" -}}
{{- toJson (list (dict "name" "http" "port" 3923 "servicePort" (int .Values.service.port) "protocol" "TCP")) -}}
{{- end -}}

{{- define "copyparty.pvcName" -}}
{{- .Values.persistence.existingClaim | default (include "quench-common.fullname" .) -}}
{{- end -}}

{{- define "copyparty.secretName" -}}
{{- .Values.admin.existingSecret | default (include "quench-common.fullname" .) -}}
{{- end -}}

{{/* copyparty's arguments: the port, the admin account (password through env expansion) and the volumes. */}}
{{- define "copyparty.args" -}}
- "-p"
- "3923"
- "-a"
- "{{ .Values.admin.username }}:$(COPYPARTY_PASSWORD)"
{{- range .Values.volumes }}
- "-v"
- {{ printf "%s:%s:%s" .path (trimPrefix "/" .url) .access | quote }}
{{- end }}
{{- range .Values.extraArgs }}
- {{ . | quote }}
{{- end }}
{{- end -}}

{{- define "copyparty.env" -}}
- name: COPYPARTY_PASSWORD
  valueFrom:
    secretKeyRef: { name: {{ include "copyparty.secretName" . }}, key: password }
# state (salts, sessions) on the data volume, hidden from listings
- { name: XDG_CONFIG_HOME, value: /srv/.copyparty }
{{- end -}}
