{{- define "frp.serviceAccountName" -}}
{{- if .Values.serviceAccount.create -}}{{ default (include "quench-common.fullname" .) .Values.serviceAccount.name }}{{- else -}}{{ default "default" .Values.serviceAccount.name }}{{- end -}}
{{- end -}}

{{/* Secret holding the client auth token and the dashboard password. */}}
{{- define "frp.secretName" -}}
{{- if .Values.auth.existingSecret -}}{{ .Values.auth.existingSecret }}{{- else -}}{{ include "quench-common.fullname" . }}{{- end -}}
{{- end -}}

{{/* Every port frps listens on, as {name, port, protocol}: the container, the Service and the
     NetworkPolicy all read this one list. */}}
{{- define "frp.ports" -}}
{{- $p := list (dict "name" "frp" "port" (int .Values.bindPort) "protocol" "TCP") (dict "name" "metrics" "port" 7600 "protocol" "TCP") -}}
{{- if .Values.dashboard.enabled }}{{ $p = append $p (dict "name" "dashboard" "port" (int .Values.dashboard.port) "protocol" "TCP") }}{{ end -}}
{{- if .Values.vhostHTTPPort }}{{ $p = append $p (dict "name" "vhost-http" "port" (int .Values.vhostHTTPPort) "protocol" "TCP") }}{{ end -}}
{{- if .Values.vhostHTTPSPort }}{{ $p = append $p (dict "name" "vhost-https" "port" (int .Values.vhostHTTPSPort) "protocol" "TCP") }}{{ end -}}
{{- range .Values.proxyPorts }}{{ $p = append $p (dict "name" .name "port" (int .port) "protocol" (default "TCP" .protocol)) }}{{ end -}}
{{- toJson $p -}}
{{- end -}}
