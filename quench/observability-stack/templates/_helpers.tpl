{{/*
Common labels for the umbrella's own glue objects. The subcharts label their
own objects via quench-common; these helpers cover the resources this chart
templates directly (kube-state-metrics, RBAC, datasource ConfigMap).
*/}}
{{- define "observability-stack.labels" -}}
helm.sh/chart: {{ printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/part-of: observability-stack
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
{{- end -}}

{{/* Fully-qualified name of the Prometheus subchart's Service/SA (quench-common
     fullname == <release>-<chart>, no fullnameOverride). */}}
{{- define "observability-stack.prometheusName" -}}
{{- printf "%s-prometheus" .Release.Name -}}
{{- end -}}

{{/* kube-state-metrics object name. */}}
{{- define "observability-stack.ksmName" -}}
{{- printf "%s-kube-state-metrics" .Release.Name -}}
{{- end -}}

{{- define "observability-stack.ksmLabels" -}}
{{ include "observability-stack.labels" . }}
app.kubernetes.io/name: kube-state-metrics
app.kubernetes.io/component: exporter
{{- end -}}

{{- define "observability-stack.ksmSelectorLabels" -}}
app.kubernetes.io/name: kube-state-metrics
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/component: exporter
{{- end -}}

{{- define "observability-stack.nodeExporterName" -}}
{{- printf "%s-node-exporter" .Release.Name -}}
{{- end -}}

{{- define "observability-stack.cadvisorName" -}}
{{- printf "%s-cadvisor" .Release.Name -}}
{{- end -}}
