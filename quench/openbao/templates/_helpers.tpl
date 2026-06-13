{{- define "openbao.serviceAccountName" -}}
{{- if .Values.serviceAccount.create -}}{{ default (include "quench-common.fullname" .) .Values.serviceAccount.name }}{{- else -}}{{ default "default" .Values.serviceAccount.name }}{{- end -}}
{{- end -}}

{{/* Headless service for stable peer DNS (raft cluster traffic on 8201, future HA). */}}
{{- define "openbao.headlessName" -}}
{{- printf "%s-headless" (include "quench-common.fullname" .) -}}
{{- end -}}

{{/* Name of the Secret holding the dev-mode root token. */}}
{{- define "openbao.devSecretName" -}}
{{- printf "%s-dev" (include "quench-common.fullname" .) -}}
{{- end -}}
