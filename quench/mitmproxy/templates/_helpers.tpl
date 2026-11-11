{{- define "mitmproxy.serviceAccountName" -}}
{{- if .Values.serviceAccount.create -}}{{ default (include "quench-common.fullname" .) .Values.serviceAccount.name }}{{- else -}}{{ default "default" .Values.serviceAccount.name }}{{- end -}}
{{- end -}}

{{- define "mitmproxy.webSecret" -}}
{{- default (printf "%s-web" (include "quench-common.fullname" .)) .Values.ui.existingSecret -}}
{{- end -}}

{{/* "regular@8080" -> 8080; a mode without @port listens on mitmproxy's default 8080 */}}
{{- define "mitmproxy.modePort" -}}
{{- $parts := splitList "@" . -}}
{{- if gt (len $parts) 1 }}{{ last $parts | int }}{{ else }}8080{{ end -}}
{{- end -}}
