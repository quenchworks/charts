{{/* Every port the server listens on, as {name, port, servicePort, protocol}: container, Service and NetworkPolicy.
     With TLS, PsiTransfer serves HTTPS on its SSL port and the plain port is not exposed. */}}
{{- define "psitransfer.ports" -}}
{{- if include "quench-common.tls.enabled" . -}}
{{- toJson (list (dict "name" "https" "port" 8443 "servicePort" (int .Values.service.port) "protocol" "TCP")) -}}
{{- else -}}
{{- toJson (list (dict "name" "http" "port" 3000 "servicePort" (int .Values.service.port) "protocol" "TCP")) -}}
{{- end -}}
{{- end -}}

{{- define "psitransfer.pvcName" -}}
{{- .Values.persistence.existingClaim | default (include "quench-common.fullname" .) -}}
{{- end -}}

{{- define "psitransfer.secretName" -}}
{{- .Values.auth.existingSecret | default (include "quench-common.fullname" .) -}}
{{- end -}}

{{/* PSITRANSFER_* settings. */}}
{{- define "psitransfer.env" -}}
- name: PSITRANSFER_ADMIN_PASS
  valueFrom:
    secretKeyRef: { name: {{ include "psitransfer.secretName" . }}, key: admin-password }
{{- if .Values.auth.uploadPassword }}
- name: PSITRANSFER_UPLOAD_PASS
  valueFrom:
    secretKeyRef: { name: {{ include "psitransfer.secretName" . }}, key: upload-password }
{{- end }}
{{- if include "quench-common.tls.enabled" . }}
- { name: PSITRANSFER_SSL_PORT, value: "8443" }
- { name: PSITRANSFER_SSL_KEY_FILE, value: /tls/tls.key }
- { name: PSITRANSFER_SSL_CERT_FILE, value: /tls/tls.crt }
{{- end }}
{{- range $k, $v := .Values.settings }}
- { name: {{ $k }}, value: {{ $v | quote }} }
{{- end }}
{{- end -}}
