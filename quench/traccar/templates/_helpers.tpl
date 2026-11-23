{{/* The web UI and API on 8082, plus one port per device protocol in devicePorts. */}}
{{- define "traccar.ports" -}}
{{- $p := list (dict "name" "http" "port" 8082 "servicePort" (int .Values.service.port) "protocol" "TCP") -}}
{{- range .Values.devicePorts }}{{ $p = append $p (dict "name" .name "port" (int .port) "servicePort" (int .port) "protocol" (.protocol | default "TCP")) }}{{ end -}}
{{- toJson $p -}}
{{- end -}}

{{- define "traccar.secretName" -}}
{{- .Values.secret.existingSecret | default (include "quench-common.fullname" .) -}}
{{- end -}}
