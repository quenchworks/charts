{{- define "nginx-proxy-manager.headlessName" -}}
{{- printf "%s-headless" (include "quench-common.fullname" .) -}}
{{- end -}}

{{- define "nginx-proxy-manager.adminSecret" -}}
{{- default (printf "%s-admin" (include "quench-common.fullname" .)) .Values.admin.existingSecret -}}
{{- end -}}
