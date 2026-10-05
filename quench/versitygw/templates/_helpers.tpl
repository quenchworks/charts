{{- define "versitygw.serviceAccountName" -}}
{{- if .Values.serviceAccount.create -}}{{ default (include "quench-common.fullname" .) .Values.serviceAccount.name }}{{- else -}}{{ default "default" .Values.serviceAccount.name }}{{- end -}}
{{- end -}}

{{/* Headless service that governs the StatefulSet (stable pod DNS) */}}
{{- define "versitygw.headlessName" -}}
{{- printf "%s-headless" (include "quench-common.fullname" .) -}}
{{- end -}}

{{/* Secret holding the root access and secret keys */}}
{{- define "versitygw.secretName" -}}
{{- default (include "quench-common.fullname" .) .Values.auth.existingSecret -}}
{{- end -}}
