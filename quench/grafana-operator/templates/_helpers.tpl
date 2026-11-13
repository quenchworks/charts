{{- define "grafana-operator.serviceAccountName" -}}
{{- if .Values.serviceAccount.create -}}{{ default (include "quench-common.fullname" .) .Values.serviceAccount.name }}{{- else -}}{{ default "default" .Values.serviceAccount.name }}{{- end -}}
{{- end -}}

{{/* The Grafana image every Grafana CR without spec.version gets (RELATED_IMAGE_GRAFANA, digest only). */}}
{{- define "grafana-operator.grafanaImage" -}}
{{- printf "%s@%s" .Values.grafanaImage.repository .Values.grafanaImage.digest -}}
{{- end -}}

{{- define "grafana-operator.ports" -}}
{{- toJson (list (dict "name" "metrics" "port" 8080 "protocol" "TCP") (dict "name" "probe" "port" 8081 "protocol" "TCP")) -}}
{{- end -}}
