{{/*
Common labels for the umbrella's own glue objects. The subcharts label their own
objects via quench-common; these helpers cover the resources this chart templates
directly (the otel-collector gateway, the datasource/dashboard ConfigMaps).
*/}}
{{- define "tracing-stack.labels" -}}
helm.sh/chart: {{ printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/part-of: tracing-stack
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
{{- end -}}

{{/* Fully-qualified name of the Tempo subchart's Service/SA (quench-common
     fullname == <release>-<chart>, no fullnameOverride). */}}
{{- define "tracing-stack.tempoName" -}}
{{- printf "%s-tempo" .Release.Name -}}
{{- end -}}

{{/* OpenTelemetry Collector object name (templated inline by this umbrella). */}}
{{- define "tracing-stack.otelCollectorName" -}}
{{- printf "%s-otel-collector" .Release.Name -}}
{{- end -}}

{{- define "tracing-stack.otelCollectorLabels" -}}
{{ include "tracing-stack.labels" . }}
app.kubernetes.io/name: otel-collector
app.kubernetes.io/component: gateway
{{- end -}}

{{- define "tracing-stack.otelCollectorSelectorLabels" -}}
app.kubernetes.io/name: otel-collector
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/component: gateway
{{- end -}}
