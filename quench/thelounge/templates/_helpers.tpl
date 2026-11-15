{{/* Every port The Lounge listens on, as {name, port, servicePort, protocol}: container, Service and NetworkPolicy. */}}
{{- define "thelounge.ports" -}}
{{- toJson (list (dict "name" (ternary "https" "http" (eq (include "quench-common.tls.enabled" .) "true")) "port" 9000 "servicePort" (int .Values.service.port) "protocol" "TCP")) -}}
{{- end -}}

{{- define "thelounge.pvcName" -}}
{{- .Values.persistence.existingClaim | default (include "quench-common.fullname" .) -}}
{{- end -}}

{{- define "thelounge.secretName" -}}
{{- .Values.admin.existingSecret | default (include "quench-common.fullname" .) -}}
{{- end -}}

{{/* The Lounge's command line: config.js entries as -c key=value overrides, then start. */}}
{{- define "thelounge.args" -}}
{{- $c := dict "public" .Values.public "reverseProxy" .Values.reverseProxy "fileUpload.enable" .Values.fileUpload "lockNetwork" .Values.lockNetwork "messageStorage" "[text]" -}}
{{- range $k, $v := .Values.defaults }}{{ $_ := set $c (printf "defaults.%s" $k) $v }}{{ end -}}
{{- if include "quench-common.tls.enabled" . }}
{{- $_ := set $c "https.enable" true }}{{ $_ := set $c "https.key" "/tls/tls.key" }}{{ $_ := set $c "https.certificate" "/tls/tls.crt" }}
{{- end }}
{{- range $k, $v := .Values.settings }}{{ $_ := set $c $k $v }}{{ end -}}
{{- range $k := keys $c | sortAlpha }}
- -c
- {{ printf "%s=%v" $k (get $c $k) | quote }}
{{- end }}
- start
{{- end -}}
