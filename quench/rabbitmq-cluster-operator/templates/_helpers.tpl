{{- define "rabbitmq-cluster-operator.serviceAccountName" -}}
{{- if .Values.serviceAccount.create -}}{{ default (include "quench-common.fullname" .) .Values.serviceAccount.name }}{{- else -}}{{ default "default" .Values.serviceAccount.name }}{{- end -}}
{{- end -}}

{{- define "rabbitmq-cluster-operator.ports" -}}
{{- toJson (list (dict "name" "metrics" "port" 8080 "protocol" "TCP") (dict "name" "probe" "port" 8081 "protocol" "TCP") (dict "name" "webhook" "port" 9443 "protocol" "TCP")) -}}
{{- end -}}
