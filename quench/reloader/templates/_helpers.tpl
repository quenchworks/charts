{{- define "reloader.serviceAccountName" -}}
{{- if .Values.serviceAccount.create -}}{{ default (include "quench-common.fullname" .) .Values.serviceAccount.name }}{{- else -}}{{ default "default" .Values.serviceAccount.name }}{{- end -}}
{{- end -}}

{{/* ClusterRole for global watching, Role when watching the release namespace only. */}}
{{- define "reloader.roleKind" -}}
{{- if .Values.watchGlobally -}}ClusterRole{{- else -}}Role{{- end -}}
{{- end -}}
