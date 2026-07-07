{{- define "forgejo.serviceAccountName" -}}
{{- if .Values.serviceAccount.create -}}{{ default (include "quench-common.fullname" .) .Values.serviceAccount.name }}{{- else -}}{{ default "default" .Values.serviceAccount.name }}{{- end -}}
{{- end -}}

{{/* Headless service that governs the StatefulSet (stable pod DNS) */}}
{{- define "forgejo.headlessName" -}}
{{- printf "%s-headless" (include "quench-common.fullname" .) -}}
{{- end -}}

{{/* ConfigMap holding the app.ini seed script */}}
{{- define "forgejo.configName" -}}
{{- printf "%s-config" (include "quench-common.fullname" .) -}}
{{- end -}}
