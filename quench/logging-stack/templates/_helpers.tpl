{{/*
Common labels for the umbrella's own glue objects. The subcharts label their
own objects via quench-common; these helpers cover the resources this chart
templates directly (Vector DaemonSet, RBAC, datasource/dashboard ConfigMaps).
*/}}
{{- define "logging-stack.labels" -}}
helm.sh/chart: {{ printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/part-of: logging-stack
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
{{- end -}}

{{/* Fully-qualified name of the Loki subchart's Service (quench-common fullname
     == <release>-<chart>, no fullnameOverride). HTTP API on port 3100. */}}
{{- define "logging-stack.lokiName" -}}
{{- printf "%s-loki" .Release.Name -}}
{{- end -}}

{{/* Vector DaemonSet object name. */}}
{{- define "logging-stack.vectorName" -}}
{{- printf "%s-vector" .Release.Name -}}
{{- end -}}

{{- define "logging-stack.vectorLabels" -}}
{{ include "logging-stack.labels" . }}
app.kubernetes.io/name: vector
app.kubernetes.io/component: log-shipper
{{- end -}}

{{- define "logging-stack.vectorSelectorLabels" -}}
app.kubernetes.io/name: vector
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/component: log-shipper
{{- end -}}
