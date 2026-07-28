{{- define "vault.serviceAccountName" -}}
{{- if .Values.serviceAccount.create -}}{{ default (include "quench-common.fullname" .) .Values.serviceAccount.name }}{{- else -}}{{ default "default" .Values.serviceAccount.name }}{{- end -}}
{{- end -}}

{{/* Headless service for stable peer DNS (Vault cluster traffic on 8201, future HA). */}}
{{- define "vault.headlessName" -}}
{{- printf "%s-headless" (include "quench-common.fullname" .) -}}
{{- end -}}

{{/* Name of the Secret holding the dev-mode root token. */}}
{{- define "vault.devSecretName" -}}
{{- printf "%s-dev" (include "quench-common.fullname" .) -}}
{{- end -}}

{{/* Name of the ConfigMap holding vault.hcl. */}}
{{- define "vault.configMapName" -}}
{{- printf "%s-config" (include "quench-common.fullname" .) -}}
{{- end -}}
