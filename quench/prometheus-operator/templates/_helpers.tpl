{{- define "prometheus-operator.serviceAccountName" -}}
{{- if .Values.serviceAccount.create -}}{{ default (include "quench-common.fullname" .) .Values.serviceAccount.name }}{{- else -}}{{ default "default" .Values.serviceAccount.name }}{{- end -}}
{{- end -}}

{{- define "prometheus-operator.reloaderImage" -}}
{{- printf "%s@%s" .Values.configReloader.repository .Values.configReloader.digest -}}
{{- end -}}

{{- define "prometheus-operator.ports" -}}
{{- toJson (list (dict "name" "http" "port" 8080 "protocol" "TCP")) -}}
{{- end -}}
