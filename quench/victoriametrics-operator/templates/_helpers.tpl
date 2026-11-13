{{- define "victoriametrics-operator.serviceAccountName" -}}
{{- if .Values.serviceAccount.create -}}{{ default (include "quench-common.fullname" .) .Values.serviceAccount.name }}{{- else -}}{{ default "default" .Values.serviceAccount.name }}{{- end -}}
{{- end -}}

{{- define "victoriametrics-operator.reloaderImage" -}}
{{- printf "%s@%s" .Values.configReloader.repository .Values.configReloader.digest -}}
{{- end -}}

{{- define "victoriametrics-operator.ports" -}}
{{- toJson (list (dict "name" "metrics" "port" 8080 "protocol" "TCP") (dict "name" "probe" "port" 8081 "protocol" "TCP")) -}}
{{- end -}}
