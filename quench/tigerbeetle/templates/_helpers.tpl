{{- define "tigerbeetle.serviceAccountName" -}}
{{- if .Values.serviceAccount.create -}}{{ default (include "quench-common.fullname" .) .Values.serviceAccount.name }}{{- else -}}{{ default "default" .Values.serviceAccount.name }}{{- end -}}
{{- end -}}

{{/* Headless service governing the StatefulSet (stable pod DNS). */}}
{{- define "tigerbeetle.headlessName" -}}
{{- printf "%s-headless" (include "quench-common.fullname" .) -}}
{{- end -}}

{{/* Absolute path of the single-replica data file. */}}
{{- define "tigerbeetle.dataFile" -}}
{{- printf "%s/0_0.tigerbeetle" .Values.dataDir -}}
{{- end -}}
