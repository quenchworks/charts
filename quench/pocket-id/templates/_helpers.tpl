{{- define "pocket-id.pvcName" -}}
{{- .Values.persistence.existingClaim | default (include "quench-common.fullname" .) -}}
{{- end -}}

{{- define "pocket-id.secretName" -}}
{{- .Values.encryptionKey.existingSecret | default (include "quench-common.fullname" .) -}}
{{- end -}}

{{/* APP_URL: the address people open; issuer in every token, so set it before the first login.
     Its host is the WebAuthn RP ID, which must be a domain or localhost: the default matches
     the port-forward the NOTES describe (a bare Service name would crash the server). */}}
{{- define "pocket-id.appUrl" -}}
{{- if and .Values.appUrl (not (regexMatch "^https?://(localhost|[^/:]+\\.[^/:]+)(:[0-9]+)?(/.*)?$" .Values.appUrl)) -}}
{{- fail (printf "appUrl %q: its host must be a domain with a dot, or localhost (it becomes the WebAuthn RP ID)" .Values.appUrl) -}}
{{- end -}}
{{- default (printf "%s://localhost:%v" (ternary "https" "http" (eq (include "quench-common.tls.enabled" .) "true")) .Values.service.port) .Values.appUrl -}}
{{- end -}}
