{{- define "coroot.serviceAccountName" -}}
{{- if .Values.serviceAccount.create -}}{{ default (include "quench-common.fullname" .) .Values.serviceAccount.name }}{{- else -}}{{ default "default" .Values.serviceAccount.name }}{{- end -}}
{{- end -}}

{{/* Headless service backing the StatefulSet (stable per-pod DNS) */}}
{{- define "coroot.headlessName" -}}
{{- printf "%s-headless" (include "quench-common.fullname" .) -}}
{{- end -}}
