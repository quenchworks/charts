{{/* Labels for the umbrella's own glue objects; the subcharts label theirs. */}}
{{- define "cache-stack.labels" -}}
helm.sh/chart: {{ printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/part-of: cache-stack
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
{{- end -}}

{{/* Subchart object names: quench-common fullname is <release>-<chart>. */}}
{{- define "cache-stack.prometheusName" -}}{{ printf "%s-prometheus" .Release.Name }}{{- end -}}
{{- define "cache-stack.valkeyName" -}}{{ printf "%s-valkey" .Release.Name }}{{- end -}}
{{- define "cache-stack.grafanaName" -}}{{ printf "%s-grafana" .Release.Name }}{{- end -}}
