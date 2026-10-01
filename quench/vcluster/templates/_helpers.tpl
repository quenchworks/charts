{{/* vCluster finds its own objects by release name (VCLUSTER_NAME): the Service
     <release>, ServiceAccounts vc-<release> and vc-workload-<release>, and the
     config Secret vc-config-<release>. Keep these names exactly. */}}
{{- define "vcluster.labels" -}}
{{ include "quench-common.labels" . }}
app: vcluster
release: {{ .Release.Name }}
{{- end -}}

{{- define "vcluster.selectorLabels" -}}
app: vcluster
release: {{ .Release.Name }}
{{- end -}}
