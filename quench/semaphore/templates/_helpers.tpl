{{/* Every port Semaphore listens on, as {name, port, servicePort, protocol}: container, Service and NetworkPolicy. */}}
{{- define "semaphore.ports" -}}
{{- toJson (list (dict "name" (ternary "https" "http" (eq (include "quench-common.tls.enabled" .) "true")) "port" 3000 "servicePort" (int .Values.service.port) "protocol" "TCP")) -}}
{{- end -}}

{{- define "semaphore.pvcName" -}}
{{- .Values.persistence.existingClaim | default (include "quench-common.fullname" .) -}}
{{- end -}}

{{- define "semaphore.secretName" -}}
{{- .Values.admin.existingSecret | default (include "quench-common.fullname" .) -}}
{{- end -}}

{{/* Keys from the Secret, shared by the server and the admin bootstrap. */}}
{{- define "semaphore.secretEnv" -}}
{{- range $env, $key := dict "SEMAPHORE_COOKIE_HASH" "cookie-hash" "SEMAPHORE_COOKIE_ENCRYPTION" "cookie-encryption" "SEMAPHORE_ACCESS_KEY_ENCRYPTION" "access-key-encryption" "ADMIN_PASSWORD" "admin-password" }}
- name: {{ $env }}
  valueFrom:
    secretKeyRef:
      name: {{ include "semaphore.secretName" $ }}
      key: {{ $key }}
{{- end }}
{{- end -}}

{{/* The app environment. */}}
{{- define "semaphore.env" -}}
{{ include "semaphore.secretEnv" . }}
{{- if include "quench-common.tls.enabled" . }}
# Semaphore serves HTTPS on 3000 from the PEM pair at /tls
- { name: SEMAPHORE_TLS_ENABLED, value: "true" }
- { name: SEMAPHORE_TLS_CERT_FILE, value: /tls/tls.crt }
- { name: SEMAPHORE_TLS_KEY_FILE, value: /tls/tls.key }
{{- end }}
{{- range $k, $v := .Values.settings }}
- { name: {{ $k }}, value: {{ $v | quote }} }
{{- end }}
{{ include "quench-common.extraEnvVars" . }}
{{- end -}}
