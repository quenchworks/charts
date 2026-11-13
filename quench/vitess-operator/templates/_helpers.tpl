{{- define "vitess-operator.serviceAccountName" -}}
{{- if .Values.serviceAccount.create -}}{{ default (include "quench-common.fullname" .) .Values.serviceAccount.name }}{{- else -}}{{ default "default" .Values.serviceAccount.name }}{{- end -}}
{{- end -}}

{{- define "vitess-operator.ports" -}}
{{- toJson (list (dict "name" "metrics" "port" 8383 "protocol" "TCP")) -}}
{{- end -}}
