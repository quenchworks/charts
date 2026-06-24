{{/*
Common labels for the umbrella's own glue objects. The subcharts label their own
objects via quench-common; these helpers cover the resources this chart templates
directly (Vector, OTel Collector, kube-state-metrics, node-exporter, VM RBAC/scrape,
the datasource/dashboard ConfigMaps).
*/}}
{{- define "lgtm-stack.labels" -}}
helm.sh/chart: {{ printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/part-of: lgtm-stack
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
{{- end -}}

{{/* Fully-qualified names of the subchart Services (quench-common fullname ==
     <release>-<chart>, no fullnameOverride). */}}
{{- define "lgtm-stack.victoriametricsName" -}}
{{- printf "%s-victoriametrics" .Release.Name -}}
{{- end -}}

{{- define "lgtm-stack.lokiName" -}}
{{- printf "%s-loki" .Release.Name -}}
{{- end -}}

{{- define "lgtm-stack.tempoName" -}}
{{- printf "%s-tempo" .Release.Name -}}
{{- end -}}

{{/* OpenTelemetry Collector object name (templated inline by this umbrella). */}}
{{- define "lgtm-stack.otelCollectorName" -}}
{{- printf "%s-otel-collector" .Release.Name -}}
{{- end -}}

{{- define "lgtm-stack.otelCollectorLabels" -}}
{{ include "lgtm-stack.labels" . }}
app.kubernetes.io/name: otel-collector
app.kubernetes.io/component: gateway
{{- end -}}

{{- define "lgtm-stack.otelCollectorSelectorLabels" -}}
app.kubernetes.io/name: otel-collector
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/component: gateway
{{- end -}}

{{/* Vector DaemonSet object name. */}}
{{- define "lgtm-stack.vectorName" -}}
{{- printf "%s-vector" .Release.Name -}}
{{- end -}}

{{- define "lgtm-stack.vectorLabels" -}}
{{ include "lgtm-stack.labels" . }}
app.kubernetes.io/name: vector
app.kubernetes.io/component: log-shipper
{{- end -}}

{{- define "lgtm-stack.vectorSelectorLabels" -}}
app.kubernetes.io/name: vector
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/component: log-shipper
{{- end -}}

{{/* kube-state-metrics object name. */}}
{{- define "lgtm-stack.ksmName" -}}
{{- printf "%s-kube-state-metrics" .Release.Name -}}
{{- end -}}

{{- define "lgtm-stack.ksmLabels" -}}
{{ include "lgtm-stack.labels" . }}
app.kubernetes.io/name: kube-state-metrics
app.kubernetes.io/component: exporter
{{- end -}}

{{- define "lgtm-stack.ksmSelectorLabels" -}}
app.kubernetes.io/name: kube-state-metrics
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/component: exporter
{{- end -}}

{{/* node-exporter object name. */}}
{{- define "lgtm-stack.nodeExporterName" -}}
{{- printf "%s-node-exporter" .Release.Name -}}
{{- end -}}
