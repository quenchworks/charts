{{/* Every port the server listens on, as {name, port, servicePort, protocol}: container, Service and NetworkPolicy. */}}
{{- define "miniserve.ports" -}}
{{- toJson (list (dict "name" (ternary "https" "http" (eq (include "quench-common.tls.enabled" .) "true")) "port" 8080 "servicePort" (int .Values.service.port) "protocol" "TCP")) -}}
{{- end -}}

{{- define "miniserve.pvcName" -}}
{{- .Values.persistence.existingClaim | default (include "quench-common.fullname" .) -}}
{{- end -}}

{{- define "miniserve.secretName" -}}
{{- .Values.auth.existingSecret | default (include "quench-common.fullname" .) -}}
{{- end -}}

{{/* MINISERVE_* settings (the image already serves /srv on 8080). */}}
{{- define "miniserve.env" -}}
{{- if .Values.auth.enabled }}
- name: MINISERVE_PASSWORD
  valueFrom:
    secretKeyRef: { name: {{ include "miniserve.secretName" . }}, key: password }
- { name: MINISERVE_AUTH, value: "{{ .Values.auth.username }}:$(MINISERVE_PASSWORD)" }
{{- end }}
{{- if .Values.uploads.enabled }}
- { name: MINISERVE_ALLOWED_UPLOAD_DIR, value: {{ join "," .Values.uploads.dirs | quote }} }
- { name: MINISERVE_MKDIR_ENABLED, value: "true" }
{{- end }}
{{- if include "quench-common.tls.enabled" . }}
- { name: MINISERVE_TLS_CERT, value: /tls/tls.crt }
- { name: MINISERVE_TLS_KEY, value: /tls/tls.key }
{{- end }}
{{- range $k, $v := .Values.settings }}
- { name: {{ $k }}, value: {{ $v | quote }} }
{{- end }}
{{- end -}}
