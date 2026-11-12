{{/* The one port Vaultwarden listens on (HTTPS when tls.enabled), as {name, port, protocol}. */}}
{{- define "vaultwarden.ports" -}}
{{- toJson (list (dict "name" "http" "port" 8080 "protocol" "TCP")) -}}
{{- end -}}

{{- define "vaultwarden.pvcName" -}}
{{- .Values.persistence.existingClaim | default (include "quench-common.fullname" .) -}}
{{- end -}}

{{- define "vaultwarden.adminSecretName" -}}
{{- .Values.admin.existingSecret | default (include "quench-common.fullname" .) -}}
{{- end -}}
