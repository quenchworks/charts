{{- define "selenium-grid.hubName" -}}
{{- printf "%s-hub" (include "quench-common.fullname" .) | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "selenium-grid.firefoxName" -}}
{{- printf "%s-node-firefox" (include "quench-common.fullname" .) | trunc 63 | trimSuffix "-" -}}
{{- end -}}
