{{- define "kafka.serviceAccountName" -}}
{{- if .Values.serviceAccount.create -}}{{ default (include "quench-common.fullname" .) .Values.serviceAccount.name }}{{- else -}}{{ default "default" .Values.serviceAccount.name }}{{- end -}}
{{- end -}}

{{- define "kafka.headlessName" -}}
{{- printf "%s-headless" (include "quench-common.fullname" .) -}}
{{- end -}}

{{/* The in-cluster address clients use to reach the broker. */}}
{{- define "kafka.advertisedHost" -}}
{{- printf "%s.%s.svc.cluster.local" (include "quench-common.fullname" .) .Release.Namespace -}}
{{- end -}}
