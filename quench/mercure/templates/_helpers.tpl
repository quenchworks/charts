{{/* Every port Mercure listens on, as {name, port, servicePort, protocol}: container, Service and NetworkPolicy. */}}
{{- define "mercure.ports" -}}
{{- toJson (list (dict "name" (ternary "https" "http" (eq (include "quench-common.tls.enabled" .) "true")) "port" 8080 "servicePort" (int .Values.service.port) "protocol" "TCP")) -}}
{{- end -}}

{{- define "mercure.secretName" -}}
{{- .Values.jwt.existingSecret | default (include "quench-common.fullname" .) -}}
{{- end -}}

{{/* MERCURE_EXTRA_DIRECTIVES: anonymous, CORS and the user's own lines. */}}
{{- define "mercure.extraDirectives" -}}
{{- $d := list -}}
{{- if .Values.anonymous }}{{ $d = append $d "anonymous" }}{{ end -}}
{{- with .Values.corsOrigins }}{{ $d = append $d (printf "cors_origins %s" (join " " .)) }}{{ end -}}
{{- with .Values.extraDirectives }}{{ $d = append $d . }}{{ end -}}
{{- join "\n" $d -}}
{{- end -}}
